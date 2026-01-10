// minizip-bridge.c
// Implementation of password-protected ZIP creation
// Compatible with pyminizip used in V1

#include "minizip-bridge.h"
#include <CommonCrypto/CommonCrypto.h>

// Traditional PKWARE encryption (for V1 compatibility)
// This matches what pyminizip uses

typedef struct {
    uint32_t keys[3];
} zip_crypto_ctx;

static void init_keys(zip_crypto_ctx* ctx, const char* password) {
    ctx->keys[0] = 305419896;
    ctx->keys[1] = 591751049;
    ctx->keys[2] = 878082192;

    while (*password) {
        uint8_t c = (uint8_t)*password++;
        ctx->keys[0] = (uint32_t)crc32(ctx->keys[0], &c, 1);
        ctx->keys[1] = ctx->keys[1] + (ctx->keys[0] & 0xff);
        ctx->keys[1] = ctx->keys[1] * 134775813 + 1;
        uint8_t temp = (uint8_t)(ctx->keys[1] >> 24);
        ctx->keys[2] = (uint32_t)crc32(ctx->keys[2], &temp, 1);
    }
}

static uint8_t decrypt_byte(zip_crypto_ctx* ctx) {
    uint16_t temp = (uint16_t)(ctx->keys[2] | 2);
    return (uint8_t)((temp * (temp ^ 1)) >> 8);
}

static uint8_t encrypt_byte(zip_crypto_ctx* ctx, uint8_t c) {
    uint8_t result = c ^ decrypt_byte(ctx);
    ctx->keys[0] = (uint32_t)crc32(ctx->keys[0], &c, 1);
    ctx->keys[1] = ctx->keys[1] + (ctx->keys[0] & 0xff);
    ctx->keys[1] = ctx->keys[1] * 134775813 + 1;
    uint8_t temp = (uint8_t)(ctx->keys[1] >> 24);
    ctx->keys[2] = (uint32_t)crc32(ctx->keys[2], &temp, 1);
    return result;
}

// ZIP Local File Header structure
#pragma pack(push, 1)
typedef struct {
    uint32_t signature;           // 0x04034b50
    uint16_t version_needed;      // 20
    uint16_t flags;               // 1 for encrypted
    uint16_t compression;         // 8 for deflate
    uint16_t mod_time;
    uint16_t mod_date;
    uint32_t crc32;
    uint32_t compressed_size;
    uint32_t uncompressed_size;
    uint16_t filename_len;
    uint16_t extra_len;
} zip_local_header;

typedef struct {
    uint32_t signature;           // 0x02014b50
    uint16_t version_made;
    uint16_t version_needed;
    uint16_t flags;
    uint16_t compression;
    uint16_t mod_time;
    uint16_t mod_date;
    uint32_t crc32;
    uint32_t compressed_size;
    uint32_t uncompressed_size;
    uint16_t filename_len;
    uint16_t extra_len;
    uint16_t comment_len;
    uint16_t disk_start;
    uint16_t internal_attr;
    uint32_t external_attr;
    uint32_t local_header_offset;
} zip_central_header;

typedef struct {
    uint32_t signature;           // 0x06054b50
    uint16_t disk_num;
    uint16_t disk_start;
    uint16_t entries_on_disk;
    uint16_t total_entries;
    uint32_t central_dir_size;
    uint32_t central_dir_offset;
    uint16_t comment_len;
} zip_end_record;
#pragma pack(pop)

static uint16_t dos_time(void) {
    time_t now = time(NULL);
    struct tm* t = localtime(&now);
    return (uint16_t)((t->tm_sec / 2) | (t->tm_min << 5) | (t->tm_hour << 11));
}

static uint16_t dos_date(void) {
    time_t now = time(NULL);
    struct tm* t = localtime(&now);
    return (uint16_t)((t->tm_mday) | ((t->tm_mon + 1) << 5) | ((t->tm_year - 80) << 9));
}

int create_password_zip(
    const char* zipPath,
    const char* inputPath,
    const char* filenameInZip,
    const char* password,
    int compressionLevel
) {
    FILE* inFile = fopen(inputPath, "rb");
    if (!inFile) return ZIP_ERRNO;

    // Read input file
    fseek(inFile, 0, SEEK_END);
    long inputSize = ftell(inFile);
    fseek(inFile, 0, SEEK_SET);

    uint8_t* inputData = (uint8_t*)malloc(inputSize);
    if (!inputData) {
        fclose(inFile);
        return ZIP_INTERNALERROR;
    }
    fread(inputData, 1, inputSize, inFile);
    fclose(inFile);

    // Calculate CRC32
    uint32_t crc = (uint32_t)crc32(0, inputData, (uInt)inputSize);

    // Compress data
    uLongf compressedSize = compressBound((uLong)inputSize);
    uint8_t* compressedData = (uint8_t*)malloc(compressedSize);
    if (!compressedData) {
        free(inputData);
        return ZIP_INTERNALERROR;
    }

    int level = (compressionLevel < 0 || compressionLevel > 9) ? 5 : compressionLevel;
    if (compress2(compressedData, &compressedSize, inputData, (uLong)inputSize, level) != Z_OK) {
        free(inputData);
        free(compressedData);
        return ZIP_INTERNALERROR;
    }
    free(inputData);

    // Skip zlib header (2 bytes) and checksum (4 bytes) for raw deflate
    uint8_t* deflateData = compressedData + 2;
    uLongf deflateSize = compressedSize - 6;

    // Encrypt if password provided
    uint8_t encryptionHeader[12];
    size_t encryptedSize = deflateSize;

    if (password && strlen(password) > 0) {
        zip_crypto_ctx ctx;
        init_keys(&ctx, password);

        // Generate random encryption header
        for (int i = 0; i < 11; i++) {
            encryptionHeader[i] = encrypt_byte(&ctx, (uint8_t)(rand() & 0xff));
        }
        // Last byte is CRC check byte
        encryptionHeader[11] = encrypt_byte(&ctx, (uint8_t)(crc >> 24));

        // Encrypt data
        for (size_t i = 0; i < deflateSize; i++) {
            deflateData[i] = encrypt_byte(&ctx, deflateData[i]);
        }
        encryptedSize = deflateSize + 12;
    }

    // Write ZIP file
    FILE* outFile = fopen(zipPath, "wb");
    if (!outFile) {
        free(compressedData);
        return ZIP_ERRNO;
    }

    size_t filenameLen = strlen(filenameInZip);

    // Local file header
    zip_local_header local = {0};
    local.signature = 0x04034b50;
    local.version_needed = 20;
    local.flags = (password && strlen(password) > 0) ? 1 : 0;
    local.compression = 8; // Deflate
    local.mod_time = dos_time();
    local.mod_date = dos_date();
    local.crc32 = crc;
    local.compressed_size = (uint32_t)encryptedSize;
    local.uncompressed_size = (uint32_t)inputSize;
    local.filename_len = (uint16_t)filenameLen;
    local.extra_len = 0;

    fwrite(&local, sizeof(local), 1, outFile);
    fwrite(filenameInZip, filenameLen, 1, outFile);

    // Write encryption header if encrypted
    if (password && strlen(password) > 0) {
        fwrite(encryptionHeader, 12, 1, outFile);
    }

    // Write compressed data
    fwrite(deflateData, deflateSize, 1, outFile);

    uint32_t centralDirOffset = (uint32_t)ftell(outFile);

    // Central directory header
    zip_central_header central = {0};
    central.signature = 0x02014b50;
    central.version_made = 20;
    central.version_needed = 20;
    central.flags = local.flags;
    central.compression = 8;
    central.mod_time = local.mod_time;
    central.mod_date = local.mod_date;
    central.crc32 = crc;
    central.compressed_size = (uint32_t)encryptedSize;
    central.uncompressed_size = (uint32_t)inputSize;
    central.filename_len = (uint16_t)filenameLen;
    central.extra_len = 0;
    central.comment_len = 0;
    central.disk_start = 0;
    central.internal_attr = 0;
    central.external_attr = 0;
    central.local_header_offset = 0;

    fwrite(&central, sizeof(central), 1, outFile);
    fwrite(filenameInZip, filenameLen, 1, outFile);

    uint32_t centralDirSize = (uint32_t)ftell(outFile) - centralDirOffset;

    // End of central directory
    zip_end_record end = {0};
    end.signature = 0x06054b50;
    end.disk_num = 0;
    end.disk_start = 0;
    end.entries_on_disk = 1;
    end.total_entries = 1;
    end.central_dir_size = centralDirSize;
    end.central_dir_offset = centralDirOffset;
    end.comment_len = 0;

    fwrite(&end, sizeof(end), 1, outFile);

    fclose(outFile);
    free(compressedData);

    return ZIP_OK;
}

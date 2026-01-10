// minizip-bridge.h
// Bridge header for minizip functionality in Swift
// Used for V1 compatible password-protected ZIP creation

#ifndef minizip_bridge_h
#define minizip_bridge_h

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <zlib.h>

// Compression levels
#define Z_BEST_COMPRESSION 9
#define Z_DEFAULT_COMPRESSION (-1)

// Minizip error codes
#define ZIP_OK 0
#define ZIP_ERRNO (-1)
#define ZIP_PARAMERROR (-102)
#define ZIP_BADZIPFILE (-103)
#define ZIP_INTERNALERROR (-104)

// Open modes
#define APPEND_STATUS_CREATE 0
#define APPEND_STATUS_CREATEAFTER 1
#define APPEND_STATUS_ADDINZIP 2

// Forward declarations
typedef void* zipFile;

// Simplified ZIP creation function
// Creates a password-protected ZIP file (V1 compatible)
int create_password_zip(
    const char* zipPath,          // Output ZIP file path
    const char* inputPath,        // Input file to compress
    const char* filenameInZip,    // Name of file inside ZIP
    const char* password,         // Encryption password
    int compressionLevel          // 0-9, use 5 for V1 compatibility
);

#endif /* minizip_bridge_h */

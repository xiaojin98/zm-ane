// AIR 原生扩展公开头（最小子集，够编 ZmWeb.m）。符号由 App 里的 AIR 运行时在最终打包时解析。
#ifndef FLASH_RUNTIME_EXTENSIONS_H
#define FLASH_RUNTIME_EXTENSIONS_H

#include <stdint.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void *FREContext;
typedef void *FREObject;

typedef enum {
    FRE_OK = 0,
    FRE_NO_SUCH_NAME = 1,
    FRE_INVALID_OBJECT = 2,
    FRE_TYPE_MISMATCH = 3,
    FRE_ACTIONSCRIPT_ERROR = 4,
    FRE_INVALID_ARGUMENT = 5,
    FRE_READ_ONLY = 6,
    FRE_WRONG_THREAD = 7,
    FRE_ILLEGAL_STATE = 8,
    FRE_INSUFFICIENT_MEMORY = 9
} FREResult;

typedef FREObject (*FREFunction)(FREContext ctx, void *functionData, uint32_t argc, FREObject argv[]);

typedef struct {
    const uint8_t *name;
    void *functionData;
    FREFunction function;
} FRENamedFunction;

typedef void (*FREContextInitializer)(void *extData, const uint8_t *ctxType, FREContext ctx,
                                      uint32_t *numFunctionsToSet, const FRENamedFunction **functionsToSet);
typedef void (*FREContextFinalizer)(FREContext ctx);

FREResult FREGetObjectAsInt32(FREObject object, int32_t *value);
FREResult FREGetObjectAsUTF8(FREObject object, uint32_t *length, const uint8_t **value);
FREResult FRENewObjectFromInt32(int32_t value, FREObject *object);
FREResult FRENewObjectFromUTF8(uint32_t length, const uint8_t *value, FREObject *object);
FREResult FREDispatchStatusEventAsync(FREContext ctx, const uint8_t *code, const uint8_t *level);

#ifdef __cplusplus
}
#endif

#endif

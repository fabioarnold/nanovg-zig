#include <stddef.h>
#include <stdint.h>

struct RiveRenderer;
struct RiveFile;
struct RiveArtboard;
struct RiveScene;

enum RivePathVerb {
    // These deliberately match Skia's values
    RIVE_PATH_VERB_MOVE = 0,
    RIVE_PATH_VERB_LINE = 1,
    RIVE_PATH_VERB_QUAD = 2,
    // conic
    RIVE_PATH_VERB_CUBIC = 4,
    RIVE_PATH_VERB_CLOSE = 5,
};

struct RivePaint {
    uint32_t color; // BGRA
    float thickness;
    uint8_t style; // 0 == stroke, 1 == fill
    uint8_t gradient; // 0 == none, 1 == linear, 2 == radial
    float sx, sy;
    float ex, ey;
    uint32_t color1;
};

struct RiveRendererInterface {
    void (*save)(void* ctx);
    void (*restore)(void* ctx);
    void (*transform)(void* ctx, const float* mat2d);
    void (*clipPath)(void* ctx, const float* points, size_t points_len, const uint8_t* verbs, size_t verbs_len);
    void (*drawPath)(void* ctx, const float* points, size_t points_len, const uint8_t* verbs, size_t verbs_len, const struct RivePaint* paint);
};

struct RiveRenderer* riveRendererCreate(void* ctx, struct RiveRendererInterface);

struct RiveFile* riveFileImport(const uint8_t* data, size_t data_size);
void riveFileDestroy(struct RiveFile* file);
size_t riveFileArtboardCount(struct RiveFile* file);
struct RiveArtboard* riveFileArtboardAt(struct RiveFile* file, size_t index);

void riveArtboardAdvance(struct RiveArtboard* artboard, float seconds);
void riveArtboardBounds(struct RiveArtboard* artboard, float* bounds);
void riveArtboardDraw(struct RiveArtboard* artboard, struct RiveRenderer* renderer);
struct RiveScene* riveArtboardAnimationAt(struct RiveArtboard* artboard, size_t index);

void riveSceneAdvanceAndApply(struct RiveScene* scene, float seconds);
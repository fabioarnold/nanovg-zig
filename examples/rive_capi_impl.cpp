extern "C" {
#include "rive_capi.h"
}

#include <vector>

#include <rive/factory.hpp>
#include <rive/file.hpp>
#include <rive/span.hpp>
#include <rive/animation/state_machine_instance.hpp>

using namespace rive;

struct RiveFile {
    std::unique_ptr<rive::File> file;
};

struct RiveArtboard {
    std::unique_ptr<rive::ArtboardInstance> artboard;
};

struct RiveScene {
    std::unique_ptr<rive::Scene> scene;
};

class NanoVGRenderShader : public RenderShader {
public:
    uint8_t gradient_type;
    float sx; // cx
    float sy; // cy
    float ex; // radius
    float ey;
    std::vector<ColorInt> colors {};
    std::vector<float> stops {};
};

class NanoVGRenderPaint : public rive::RenderPaint {
public:
    RivePaint paint {};

    void color(unsigned int value) override { paint.color = value; }
    void style(RenderPaintStyle value) override { paint.style = (uint8_t)value; }
    void thickness(float value) override { paint.thickness = value; }
    void join(StrokeJoin value) override {}
    void cap(StrokeCap value) override {}
    void blendMode(BlendMode value) override {}
    void shader(rcp<RenderShader> shader) override {
        auto nvg_shader = (NanoVGRenderShader*)shader.get();
        paint.gradient = 1 + nvg_shader->gradient_type;
        paint.sx = nvg_shader->sx;
        paint.sy = nvg_shader->sy;
        paint.ex = nvg_shader->ex;
        paint.ey = nvg_shader->ey;
        paint.color = nvg_shader->colors[0];
        paint.color1 = nvg_shader->colors[1];
    }
    void invalidateStroke() override {}
};

class NanoVGRenderPath : public rive::RenderPath {
public:
    std::vector<Vec2D> points;
    std::vector<uint8_t> verbs;

    NanoVGRenderPath() {};
    NanoVGRenderPath(rive::RawPath& rawPath);

    void reset() override;
    void addRenderPath(RenderPath* path, const Mat2D& transform) override;
    void fillRule(FillRule value) override;
    void moveTo(float x, float y) override;
    void lineTo(float x, float y) override;
    void cubicTo(float ox, float oy, float ix, float iy, float x, float y) override;
    void close() override;
};

class NanoVGRenderer : public rive::Renderer {
private:
    void* ctx;
    RiveRendererInterface interface;

public:
    NanoVGRenderer(void* ctx, RiveRendererInterface interface) : ctx(ctx), interface(interface) {}

    virtual void save() override;
    virtual void restore() override;
    virtual void transform(const Mat2D& transform) override;
    virtual void drawPath(RenderPath* path, RenderPaint* paint) override;
    virtual void clipPath(RenderPath* path) override;
    virtual void drawImage(const RenderImage*, BlendMode, float opacity) override;
    virtual void drawImageMesh(const RenderImage*,
                               rcp<RenderBuffer> vertices_f32,
                               rcp<RenderBuffer> uvCoords_f32,
                               rcp<RenderBuffer> indices_u16,
                               BlendMode,
                               float opacity) override;
};

NanoVGRenderPath::NanoVGRenderPath(rive::RawPath& rawPath) {
    points.assign(rawPath.points().begin(), rawPath.points().end());
    verbs.assign(rawPath.verbsU8().begin(), rawPath.verbsU8().end());
}

void NanoVGRenderPath::fillRule(FillRule value) {
    // TODO always non-zero?
    if (value == FillRule::evenOdd) {
        printf("evenOdd\n");
    }
}

void NanoVGRenderPath::reset() {
    points.clear();
    verbs.clear();
}

void NanoVGRenderPath::addRenderPath(RenderPath* path, const Mat2D& transform) {
    auto nvg_path = (NanoVGRenderPath*)path;
    auto n = points.size();
    points.resize(n + nvg_path->points.size());
    transform.mapPoints(&points[n], &nvg_path->points[0], nvg_path->points.size());
    verbs.insert(verbs.end(), nvg_path->verbs.begin(), nvg_path->verbs.end());
}

void NanoVGRenderPath::moveTo(float x, float y) {
    verbs.push_back(RIVE_PATH_VERB_MOVE);
    points.push_back(Vec2D {x, y});
}

void NanoVGRenderPath::lineTo(float x, float y) {
    verbs.push_back(RIVE_PATH_VERB_LINE);
    points.push_back(Vec2D {x, y});
}

void NanoVGRenderPath::cubicTo(float ox, float oy, float ix, float iy, float x, float y) {
    verbs.push_back(RIVE_PATH_VERB_CUBIC);
    points.push_back(Vec2D {ox, oy});
    points.push_back(Vec2D {ix, iy});
    points.push_back(Vec2D {x, y});
}

void NanoVGRenderPath::close() {
    verbs.push_back(RIVE_PATH_VERB_CLOSE);
}

void NanoVGRenderer::save() {
    interface.save(ctx);
}

void NanoVGRenderer::restore() {
    interface.restore(ctx);
}

void NanoVGRenderer::transform(const Mat2D& transform) {
    interface.transform(ctx, transform.values());
}

void NanoVGRenderer::drawPath(RenderPath* path, RenderPaint* paint) {
    auto nvg_path = (NanoVGRenderPath*)path;
    auto nvg_paint = (NanoVGRenderPaint*)paint;
    interface.drawPath(ctx,
        (const float*)nvg_path->points.data(), 2 * nvg_path->points.size(), nvg_path->verbs.data(), nvg_path->verbs.size(),
        &nvg_paint->paint);
}

void NanoVGRenderer::clipPath(RenderPath* path) {
    auto nvg_path = (NanoVGRenderPath*)path;
    interface.clipPath(ctx, (const float*)nvg_path->points.data(), 2 * nvg_path->points.size(), nvg_path->verbs.data(), nvg_path->verbs.size());
}

void NanoVGRenderer::drawImage(const RenderImage*, BlendMode, float opacity) {
    // TODO
}

void NanoVGRenderer::drawImageMesh(const RenderImage*,
                               rcp<RenderBuffer> vertices_f32,
                               rcp<RenderBuffer> uvCoords_f32,
                               rcp<RenderBuffer> indices_u16,
                               BlendMode,
                               float opacity) {
    // TODO
}

struct RiveRenderer {
    std::unique_ptr<rive::Renderer> renderer;
};

RiveRenderer* riveRendererCreate(void* ctx, RiveRendererInterface interface) {
    auto renderer = new RiveRenderer {};
    renderer->renderer = std::make_unique<NanoVGRenderer>(ctx, interface);
    return renderer;
}

class NanoVGFactory : public Factory
{
public:
    rcp<RenderBuffer> makeBufferU16(Span<const uint16_t>) override;
    rcp<RenderBuffer> makeBufferU32(Span<const uint32_t>) override;
    rcp<RenderBuffer> makeBufferF32(Span<const float>) override;

    rcp<RenderShader> makeLinearGradient(float sx,
                                         float sy,
                                         float ex,
                                         float ey,
                                         const ColorInt colors[], // [count]
                                         const float stops[],     // [count]
                                         size_t count) override;

    rcp<RenderShader> makeRadialGradient(float cx,
                                         float cy,
                                         float radius,
                                         const ColorInt colors[], // [count]
                                         const float stops[],     // [count]
                                         size_t count) override;

    std::unique_ptr<RenderPath> makeRenderPath(RawPath&, FillRule) override;

    std::unique_ptr<RenderPath> makeEmptyRenderPath() override;

    std::unique_ptr<RenderPaint> makeRenderPaint() override;

    std::unique_ptr<RenderImage> decodeImage(Span<const uint8_t>) override;
};

rcp<RenderBuffer> NanoVGFactory::makeBufferU16(Span<const uint16_t>) {
    return nullptr;
}

rcp<RenderBuffer> NanoVGFactory::makeBufferU32(Span<const uint32_t>) {
    return nullptr;
}

rcp<RenderBuffer> NanoVGFactory::makeBufferF32(Span<const float>) {
    return nullptr;
}

rcp<RenderShader> NanoVGFactory::makeLinearGradient(float sx,
                                        float sy,
                                        float ex,
                                        float ey,
                                        const ColorInt colors[], // [count]
                                        const float stops[],     // [count]
                                        size_t count) {
    auto shader = new NanoVGRenderShader();
    shader->gradient_type = 0,
    shader->sx = sx,
    shader->sy = sy,
    shader->ex = ex,
    shader->ey = ey,
    shader->colors.assign(colors, colors + count);
    shader->stops.assign(stops, stops + count);
    return rcp<RenderShader>(shader);
}

rcp<RenderShader> NanoVGFactory::makeRadialGradient(float cx,
                                    float cy,
                                    float radius,
                                    const ColorInt colors[], // [count]
                                    const float stops[],     // [count]
                                    size_t count) {
    auto shader = new NanoVGRenderShader();
    shader->gradient_type = 1,
    shader->sx = cx,
    shader->sy = cy,
    shader->ex = radius,
    shader->colors.assign(colors, colors + count);
    shader->stops.assign(stops, stops + count);
    return rcp<RenderShader>(shader);
}

std::unique_ptr<RenderPath> NanoVGFactory::makeRenderPath(RawPath& rawPath, FillRule) {
    return std::make_unique<NanoVGRenderPath>(rawPath);
}

std::unique_ptr<RenderPath> NanoVGFactory::makeEmptyRenderPath() {
    return std::make_unique<NanoVGRenderPath>();
}

std::unique_ptr<RenderPaint> NanoVGFactory::makeRenderPaint() {
    return std::make_unique<NanoVGRenderPaint>();
}

std::unique_ptr<RenderImage> NanoVGFactory::decodeImage(Span<const uint8_t>) {
    return nullptr;
}

static NanoVGFactory g_factory;

RiveFile* riveFileImport(const uint8_t* data, size_t data_size) {
    auto file = new RiveFile {};
    file->file = rive::File::import(rive::Span<const uint8_t>(data, data_size), &g_factory);
    return file;
}

void riveFileDestroy(RiveFile* file) {
    delete file;
}

size_t riveFileArtboardCount(RiveFile* file) {
    return file->file->artboardCount();
}

RiveArtboard* riveFileArtboardAt(RiveFile* file, size_t index) {
    auto artboard = new RiveArtboard {};
    artboard->artboard = file->file->artboardAt(index);
    return artboard;
}

void riveArtboardAdvance(struct RiveArtboard* artboard, float seconds) {
    artboard->artboard->advance(seconds);
}

void riveArtboardBounds(RiveArtboard* artboard, float* bounds) {
    auto aabb = artboard->artboard->bounds();
    bounds[0] = aabb.minX;
    bounds[1] = aabb.minY;
    bounds[2] = aabb.maxX;
    bounds[3] = aabb.maxY;
}

void riveArtboardDraw(struct RiveArtboard* artboard, struct RiveRenderer* renderer) {
    artboard->artboard->draw(renderer->renderer.get());
}

RiveScene* riveArtboardAnimationAt(RiveArtboard* artboard, size_t index) {
    auto scene = new RiveScene {};
    scene->scene = artboard->artboard->animationAt(index);
    return scene;
}

void riveSceneAdvanceAndApply(RiveScene* scene, float seconds) {
    scene->scene->advanceAndApply(seconds);
}
<template>
  <div ref="parent" class="simple-fill-container">
    <canvas ref="canvasEl" class="simple-fill-canvas"></canvas>
  </div>
</template>

<script>
export default {
  name: 'SimpleFill',
  props: {
    amazonGeoJSON: {
      type: Object,
      default: null
    },
    maxPoints: {
      type: Number,
      default: 6000
    },
    spawnPerFrame: {
      type: Number,
      default: 150
    },
    pointRadius: {
      type: Number,
      default: 6
    },
    fadeDuration: {
      type: Number,
      default: 4000
    },
    initialPalette: {
      type: Array,
      default: () => [
        '#d0f0d7',
        '#a4e6bb',
        '#77dca0',
        '#4fc287',
        '#3ca36f'
      ]
    },
    finalColor: {
      type: String,
      default: '#1b4332'
    },
    backgroundColor: {
      type: String,
      default: '#ffffff'
    },
    borderColor: {
      type: String,
      default: '#000000'
    },
    seed: {
      type: Number,
      default: null
    },
    canvasPadding: {
      type: Number,
      default: 20
    }
  },
  data() {
    return {
      rafId: null,
      resizeObserver: null,
      amazonPath: null,
      bounds: null,
      points: [],
      offscreenCtx: null,
      startTime: null,
      animationComplete: false,
      rand: null,
      initialPaletteRgb: [],
      finalColorRgb: { r: 27, g: 67, b: 50 },
      canvasReady: false,
      pointQueue: [],
      pointQueueIndex: 0,
      targetPointCount: 0,
      firstPointTime: null,
      lastPointTime: null
    }
  },
  watch: {
    amazonGeoJSON: {
      handler() {
        this.setupAmazon()
      },
      immediate: true
    },
    maxPoints() {
      if (!this.canvasReady) return
      this.restartAnimation()
    },
    spawnPerFrame() {
      if (!this.canvasReady) return
      this.restartAnimation()
    },
    pointRadius() {
      if (!this.canvasReady) return
      this.draw(this.getNow())
    },
    fadeDuration() {
      if (!this.canvasReady) return
      this.restartAnimation()
    },
    initialPalette: {
      handler() {
        if (!this.canvasReady) return
        this.updateColorPalette()
        this.restartAnimation()
      },
      deep: true
    },
    finalColor() {
      if (!this.canvasReady) return
      this.updateColorPalette()
      this.draw(this.getNow())
    },
    seed() {
      if (!this.canvasReady) return
      this.setupRandom()
      this.restartAnimation()
    }
  },
  mounted() {
    this.initCanvas()
    this.canvasReady = true
    this.setupRandom()
    this.updateColorPalette()
    this.setupAmazon()
  },
  beforeUnmount() {
    if (this.rafId) {
      cancelAnimationFrame(this.rafId)
      this.rafId = null
    }
    if (this.resizeObserver) {
      this.resizeObserver.disconnect()
      this.resizeObserver = null
    }
    this.offscreenCtx = null
  },
  methods: {
    initCanvas() {
      const canvas = this.$refs.canvasEl
      const container = this.$refs.parent
      if (!canvas || !container) return

      const offscreenCanvas = document.createElement('canvas')
      this.offscreenCtx = offscreenCanvas.getContext('2d')

      this.resizeObserver = new ResizeObserver(() => {
        this.resizeCanvas()
      })
      this.resizeObserver.observe(container)

      this.resizeCanvas()
    },

    resizeCanvas() {
      const canvas = this.$refs.canvasEl
      if (!canvas) return

      const dpr = Math.max(1, window.devicePixelRatio || 1)
      const rect = canvas.getBoundingClientRect()

      canvas.width = Math.floor(rect.width * dpr)
      canvas.height = Math.floor(rect.height * dpr)

      const ctx = canvas.getContext('2d')
      ctx.setTransform(1, 0, 0, 1, 0, 0)
      ctx.scale(dpr, dpr)

      if (this.amazonPath) {
        this.draw(this.getNow())
      }
    },

    setupAmazon() {
      if (!this.canvasReady) {
        return
      }

      if (!this.amazonGeoJSON) {
        this.amazonPath = null
        this.bounds = null
        this.points = []
        this.pointQueue = []
        this.pointQueueIndex = 0
        this.targetPointCount = 0
        this.animationComplete = true
        this.draw(this.getNow())
        return
      }

      this.amazonPath = this.buildPathFromGeoJSON(this.amazonGeoJSON)
      if (!this.amazonPath) {
        return
      }

      this.updateBounds(this.amazonGeoJSON)
      this.restartAnimation()
    },

    setupRandom() {
      if (Number.isFinite(this.seed)) {
        this.rand = this.mulberry32(this.seed)
      } else {
        this.rand = null
      }
    },

    updateColorPalette() {
      const palette = Array.isArray(this.initialPalette) ? this.initialPalette : []
      this.initialPaletteRgb = palette
        .map(color => this.hexToRgb(color))
        .filter(Boolean)

      const finalRgb = this.hexToRgb(this.finalColor)
      if (finalRgb) {
        this.finalColorRgb = finalRgb
      }
    },

    restartAnimation() {
      if (!this.amazonPath || !this.bounds) {
        return
      }

      if (this.rafId) {
        cancelAnimationFrame(this.rafId)
        this.rafId = null
      }

      if (Number.isFinite(this.seed)) {
        this.setupRandom()
      }

      this.points = []
      this.animationComplete = false
      this.firstPointTime = null
      this.lastPointTime = null
      this.pointQueueIndex = 0
      this.generatePointQueue()
      if (this.pointQueue.length === 0) {
        this.targetPointCount = 0
        this.draw(this.getNow())
        return
      }
      this.targetPointCount = this.pointQueue.length
      this.startTime = this.getNow()

      this.draw(this.startTime)
      this.animate()
    },

    generatePointQueue() {
      this.pointQueue = []
      this.pointQueueIndex = 0

      if (!this.bounds || !this.amazonPath || !this.offscreenCtx) {
        return
      }

      const width = this.bounds.maxX - this.bounds.minX
      const height = this.bounds.maxY - this.bounds.minY
      if (width <= 0 || height <= 0) {
        return
      }

      this.offscreenCtx.setTransform(1, 0, 0, 1, 0, 0)

      const targetPoints = Math.max(1, Math.floor(this.maxPoints))
      const totalArea = width * height
      const cellSize = Math.max(Math.sqrt(totalArea / targetPoints), 1e-6)
      const cols = Math.max(1, Math.ceil(width / cellSize))
      const rows = Math.max(1, Math.ceil(height / cellSize))

      for (let row = 0; row < rows; row += 1) {
        if (this.pointQueue.length >= targetPoints) {
          break
        }
        for (let col = 0; col < cols; col += 1) {
          if (this.pointQueue.length >= targetPoints) {
            break
          }

          const cellMinX = this.bounds.minX + col * cellSize
          const cellMinY = this.bounds.minY + row * cellSize

          const attemptsPerCell = 6
          for (let attempt = 0; attempt < attemptsPerCell; attempt += 1) {
            const x = cellMinX + this.random() * cellSize
            const y = cellMinY + this.random() * cellSize
            if (this.offscreenCtx.isPointInPath(this.amazonPath, x, y)) {
              this.pointQueue.push({ x, y })
              break
            }
          }
        }
      }

      let fallbackAttempts = 0
      const maxFallbackAttempts = targetPoints * 40
      while (this.pointQueue.length < targetPoints && fallbackAttempts < maxFallbackAttempts) {
        const fallback = this.randomPointInAmazon()
        if (fallback) {
          this.pointQueue.push(fallback)
        }
        fallbackAttempts += 1
      }

      if (this.pointQueue.length > targetPoints) {
        this.pointQueue.length = targetPoints
      }

      this.shuffleQueue(this.pointQueue)
    },

    animate() {
      const now = this.getNow()
      this.spawnPoints(now)
      this.draw(now)

      if (!this.animationComplete) {
        this.rafId = requestAnimationFrame(() => this.animate())
      } else {
        this.rafId = null
      }
    },

    spawnPoints(now) {
      if (!this.bounds || !this.amazonPath) {
        return
      }

      const targetTotal = this.targetPointCount || Math.max(0, Math.floor(this.maxPoints))
      const remaining = Math.max(0, targetTotal - this.points.length)

      if (remaining > 0) {
        const targetSpawn = Math.min(this.spawnPerFrame, remaining)
        let spawned = 0

        while (spawned < targetSpawn && this.pointQueueIndex < this.pointQueue.length) {
          const position = this.pointQueue[this.pointQueueIndex]
          this.pointQueueIndex += 1
          if (this.createPoint(position, now)) {
            spawned += 1
          }
        }

        if (spawned < targetSpawn) {
          let attempts = 0
          const maxAttempts = (targetSpawn - spawned) * 40
          while (spawned < targetSpawn && attempts < maxAttempts) {
            attempts += 1
            const fallbackPosition = this.randomPointInAmazon()
            if (!fallbackPosition) {
              continue
            }
            if (this.createPoint(fallbackPosition, now)) {
              spawned += 1
            }
          }
        }
      }

      if (this.points.length < targetTotal) {
        this.animationComplete = false
      } else if (this.fadeDuration <= 0) {
        this.animationComplete = true
      } else if (this.lastPointTime !== null && now - this.lastPointTime >= this.fadeDuration) {
        this.animationComplete = true
      } else {
        this.animationComplete = false
      }
    },

    draw(now = this.getNow()) {
      if (!this.canvasReady) {
        return
      }

      const canvas = this.$refs.canvasEl
      if (!canvas) return

      const ctx = canvas.getContext('2d')
      const dpr = window.devicePixelRatio || 1
      const width = canvas.width / dpr
      const height = canvas.height / dpr

      ctx.save()
      ctx.setTransform(1, 0, 0, 1, 0, 0)
      ctx.clearRect(0, 0, width, height)

      ctx.fillStyle = this.backgroundColor
      ctx.fillRect(0, 0, width, height)

      if (!this.bounds || !this.amazonPath) {
        ctx.restore()
        return
      }

      const pad = Math.max(0, this.canvasPadding)
      const boundsWidth = this.bounds.maxX - this.bounds.minX
      const boundsHeight = this.bounds.maxY - this.bounds.minY
      const scale = Math.min(
        (width - 2 * pad) / boundsWidth,
        (height - 2 * pad) / boundsHeight
      )

      const tx = (width - scale * boundsWidth) / 2 - scale * this.bounds.minX
      const ty = (height - scale * boundsHeight) / 2 - scale * this.bounds.minY

      ctx.translate(tx, ty)
      ctx.scale(scale, scale)

      ctx.save()
      ctx.clip(this.amazonPath)

      const radius = Math.max(0.5, this.pointRadius) / scale
      const effectiveFade = Math.max(0, this.fadeDuration)

      for (let i = 0; i < this.points.length; i += 1) {
        const point = this.points[i]
        const life = now - point.spawnTime
        if (life < 0) continue

        const t = effectiveFade === 0 ? 1 : Math.min(1, life / effectiveFade)
        const color = this.interpolateColor(point.initialColor, point.targetColor, t)

        ctx.fillStyle = `rgba(${color.r}, ${color.g}, ${color.b}, 1)`
        ctx.beginPath()
        ctx.arc(point.x, point.y, radius, 0, Math.PI * 2)
        ctx.fill()
      }

      ctx.restore()

      ctx.strokeStyle = this.borderColor
      ctx.lineWidth = 1.5 / scale
      ctx.stroke(this.amazonPath)

      ctx.restore()
    },

    createPoint(position, now) {
      if (!position) {
        return false
      }

      const initialColor = this.randomInitialColor()
      this.points.push({
        x: position.x,
        y: position.y,
        spawnTime: now,
        initialColor,
        targetColor: { ...this.finalColorRgb }
      })

      if (this.firstPointTime === null) {
        this.firstPointTime = now
      }
      this.lastPointTime = now
      return true
    },

    shuffleQueue(array) {
      for (let i = array.length - 1; i > 0; i -= 1) {
        const j = Math.floor(this.random() * (i + 1))
        const temp = array[i]
        array[i] = array[j]
        array[j] = temp
      }
    },

    randomPointInAmazon() {
      if (!this.bounds || !this.amazonPath || !this.offscreenCtx) {
        return null
      }

      this.offscreenCtx.setTransform(1, 0, 0, 1, 0, 0)
      const width = this.bounds.maxX - this.bounds.minX
      const height = this.bounds.maxY - this.bounds.minY

      for (let i = 0; i < 200; i += 1) {
        const x = this.bounds.minX + this.random() * width
        const y = this.bounds.minY + this.random() * height

        if (this.offscreenCtx.isPointInPath(this.amazonPath, x, y)) {
          return { x, y }
        }
      }

      return null
    },

    randomInitialColor() {
      if (!this.initialPaletteRgb.length) {
        return { ...this.finalColorRgb }
      }
      const index = Math.floor(this.random() * this.initialPaletteRgb.length)
      const color = this.initialPaletteRgb[index]
      return { r: color.r, g: color.g, b: color.b }
    },

    interpolateColor(start, end, t) {
      return {
        r: Math.round(start.r + (end.r - start.r) * t),
        g: Math.round(start.g + (end.g - start.g) * t),
        b: Math.round(start.b + (end.b - start.b) * t)
      }
    },

    random() {
      if (this.rand) {
        return this.rand()
      }
      return Math.random()
    },

    getNow() {
      if (typeof performance !== 'undefined' && performance.now) {
        return performance.now()
      }
      return Date.now()
    },

    buildPathFromGeoJSON(geojson) {
      try {
        const path = new Path2D()

        if (geojson.type === 'FeatureCollection') {
          geojson.features.forEach(feature => {
            this.addGeometryToPath(path, feature.geometry)
          })
        } else {
          const geom = geojson.type === 'Feature' ? geojson.geometry : geojson
          this.addGeometryToPath(path, geom)
        }

        return path
      } catch (error) {
        console.error('Error building path from GeoJSON:', error)
        return null
      }
    },

    addGeometryToPath(path, geometry) {
      if (!geometry) return

      if (geometry.type === 'Polygon') {
        this.addPolygonToPath(path, geometry.coordinates)
      } else if (geometry.type === 'MultiPolygon') {
        geometry.coordinates.forEach(poly => {
          this.addPolygonToPath(path, poly)
        })
      }
    },

    addPolygonToPath(path, coordinates) {
      if (!Array.isArray(coordinates)) return

      coordinates.forEach(ring => {
        ring.forEach((coord, coordIndex) => {
          const [x, y] = coord
          const flippedY = -y
          if (coordIndex === 0) {
            path.moveTo(x, flippedY)
          } else {
            path.lineTo(x, flippedY)
          }
        })
        path.closePath()
      })
    },

    updateBounds(geojson) {
      let minX = Infinity
      let minY = Infinity
      let maxX = -Infinity
      let maxY = -Infinity

      const processCoords = (coords) => {
        if (Array.isArray(coords[0])) {
          coords.forEach(c => processCoords(c))
        } else {
          const [x, y] = coords
          if (x < minX) minX = x
          if (y < minY) minY = y
          if (x > maxX) maxX = x
          if (y > maxY) maxY = y
        }
      }

      if (geojson.type === 'FeatureCollection') {
        geojson.features.forEach(feature => {
          const geom = feature.geometry
          if (geom.type === 'Polygon') {
            geom.coordinates.forEach(ring => processCoords(ring))
          } else if (geom.type === 'MultiPolygon') {
            geom.coordinates.forEach(poly => {
              poly.forEach(ring => processCoords(ring))
            })
          }
        })
      } else {
        const geom = geojson.type === 'Feature' ? geojson.geometry : geojson

        if (geom.type === 'Polygon') {
          geom.coordinates.forEach(ring => processCoords(ring))
        } else if (geom.type === 'MultiPolygon') {
          geom.coordinates.forEach(poly => {
            poly.forEach(ring => processCoords(ring))
          })
        }
      }

      if (minX === Infinity || minY === Infinity || maxX === -Infinity || maxY === -Infinity) {
        this.bounds = null
        return
      }

      const flippedMinY = -maxY
      const flippedMaxY = -minY
      this.bounds = { minX, minY: flippedMinY, maxX, maxY: flippedMaxY }
    },

    mulberry32(seed) {
      let a = seed
      return function() {
        let t = (a += 0x6d2b79f5)
        t = Math.imul(t ^ (t >>> 15), t | 1)
        t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296
      }
    },

    hexToRgb(hex) {
      if (typeof hex !== 'string') return null
      const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex.trim())
      if (!result) return null
      return {
        r: parseInt(result[1], 16),
        g: parseInt(result[2], 16),
        b: parseInt(result[3], 16)
      }
    }
  }
}
</script>

<style scoped>
.simple-fill-container {
  width: 100%;
  height: 100%;
  position: relative;
  min-height: 300px;
}

.simple-fill-canvas {
  width: 100%;
  height: 100%;
  display: block;
}
</style>


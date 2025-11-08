<template>
  <div class="geojson-viewer">
    <svg
      v-if="paths.length"
      :viewBox="viewBox"
      class="geojson-svg"
      :style="svgStyle"
      role="img"
      aria-label="Amazon GeoJSON"
      xmlns="http://www.w3.org/2000/svg"
    >
      <g class="geojson-group">
        <path
          v-for="path in paths"
          :key="path.id"
          :d="path.d"
          :fill="pathFill"
          :stroke="strokeColor"
          :fill-opacity="pathFillOpacity"
          :stroke-width="strokeWidth"
          :stroke-linejoin="strokeLinejoin"
          :stroke-linecap="strokeLinecap"
          :stroke-opacity="pathStrokeOpacity"
          class="geojson-path"
          ref="geoPaths"
        />
      </g>
    </svg>

    <div v-else class="geojson-empty">
      <slot name="loading">Loading Amazon GeoJSON…</slot>
    </div>
  </div>
</template>

<script>
export default {
  name: 'Animation',
  emits: ['fill-progress'],
  props: {
    amazonGeoJSON: {
      type: Object,
      required: true
    },
    width: {
      type: Number,
      default: 960
    },
    height: {
      type: Number,
      default: 540
    },
    padding: {
      type: Number,
      default: 24
    },
    strokeColor: {
      type: String,
      default: '#1b4332'
    },
    strokeWidth: {
      type: Number,
      default: 1
    },
    strokeOpacity: {
      type: Number,
      default: 1
    },
    strokeLinejoin: {
      type: String,
      default: 'round'
    },
    strokeLinecap: {
      type: String,
      default: 'round'
    },
    fillColor: {
      type: String,
      default: '#006400'
    },
    fillOpacity: {
      type: Number,
      default: 0.12
    },
    fillFadeDuration: {
      type: Number,
      default: 3500
    },
    outlineDuration: {
      type: Number,
      default: 1800
    },
    outlineDelay: {
      type: Number,
      default: 200
    },
    backgroundColor: {
      type: String,
      default: 'transparent'
    }
  },
  data() {
    return {
      fillAnimationStart: null,
      fillRafId: null,
      currentFillOpacity: 0,
      outlineAnimationTimeout: null,
      outlineAnimationStarted: false,
      outlineAnimationCompleted: false
    }
  },
  computed: {
    features() {
      if (!this.amazonGeoJSON) return []
      if (Array.isArray(this.amazonGeoJSON.features)) {
        return this.amazonGeoJSON.features
      }
      if (this.amazonGeoJSON.type === 'Feature') {
        return [this.amazonGeoJSON]
      }
      return []
    },
    bounds() {
      if (!this.features.length) return null
      const bounds = {
        minLng: Infinity,
        minLat: Infinity,
        maxLng: -Infinity,
        maxLat: -Infinity
      }

      this.features.forEach((feature) => {
        this.walkCoordinates(feature.geometry, ([lng, lat]) => {
          if (typeof lng !== 'number' || typeof lat !== 'number') return
          bounds.minLng = Math.min(bounds.minLng, lng)
          bounds.maxLng = Math.max(bounds.maxLng, lng)
          bounds.minLat = Math.min(bounds.minLat, lat)
          bounds.maxLat = Math.max(bounds.maxLat, lat)
        })
      })

      if (
        !isFinite(bounds.minLng) ||
        !isFinite(bounds.minLat) ||
        !isFinite(bounds.maxLng) ||
        !isFinite(bounds.maxLat)
      ) {
        return null
      }

      return bounds
    },
    viewBox() {
      return `0 0 ${this.width} ${this.height}`
    },
    scaleInfo() {
      if (!this.bounds) return null
      const { minLng, maxLng, minLat, maxLat } = this.bounds
      const drawableWidth = Math.max(this.width - this.padding * 2, 1)
      const drawableHeight = Math.max(this.height - this.padding * 2, 1)
      const lngRange = Math.max(maxLng - minLng, 1e-6)
      const latRange = Math.max(maxLat - minLat, 1e-6)
      const factor = Math.min(drawableWidth / lngRange, drawableHeight / latRange)
      const widthUsed = lngRange * factor
      const heightUsed = latRange * factor
      const paddingX = Math.max(this.padding, (this.width - widthUsed) / 2)
      const paddingY = Math.max(this.padding, (this.height - heightUsed) / 2)

      return {
        factor,
        minLng,
        maxLat,
        paddingX,
        paddingY
      }
    },
    paths() {
      const info = this.scaleInfo
      if (!info) return []

      const { factor, minLng, maxLat, paddingX, paddingY } = info
      let id = 0

      const projectPoint = (coord) => {
        if (!Array.isArray(coord) || coord.length < 2) return null
        const [lng, lat] = coord
        if (typeof lng !== 'number' || typeof lat !== 'number') return null

        const x = paddingX + (lng - minLng) * factor
        const y = paddingY + (maxLat - lat) * factor
        return `${x.toFixed(2)} ${y.toFixed(2)}`
      }

      const paths = []
      this.features.forEach((feature, featureIndex) => {
        this.walkPolygons(feature.geometry, (polygon) => {
          const parts = polygon
            .map((ring) => {
              const commands = ring
                .map((coord, index) => {
                  const point = projectPoint(coord)
                  if (!point) return null
                  const move = index === 0 ? 'M' : 'L'
                  return `${move}${point}`
                })
                .filter(Boolean)

              if (commands.length < 3) return null
              return `${commands.join(' ')} Z`
            })
            .filter(Boolean)

          if (parts.length) {
            paths.push({
              id: `${feature.id || featureIndex}-${id++}`,
              d: parts.join(' ')
            })
          }
        })
      })

      return paths
    },
    pathFill() {
      if (!this.fillColor || this.fillColor === 'none' || this.fillColor.toLowerCase() === 'transparent') {
        return 'none'
      }
      return this.fillColor
    },
    pathFillOpacity() {
      if (this.pathFill === 'none') {
        return 0
      }
      const target = Math.min(Math.max(this.fillOpacity, 0), 1)
      return Math.min(this.currentFillOpacity, target)
    },
    pathStrokeOpacity() {
      return Math.min(Math.max(this.strokeOpacity, 0), 1)
    },
    svgStyle() {
      return {
        backgroundColor: this.backgroundColor
      }
    }
  },
  watch: {
    amazonGeoJSON: {
      handler() {
        this.restartAnimations()
      },
      immediate: true
    },
    fillOpacity() {
      this.restartAnimations()
    },
    fillColor() {
      this.restartAnimations()
    },
    pathFill(newVal, oldVal) {
      if (newVal !== oldVal) {
        this.restartAnimations()
      }
    },
    paths(newPaths, oldPaths) {
      if (newPaths !== oldPaths) {
        this.restartAnimations()
      }
    },
    outlineDuration() {
      this.restartAnimations()
    },
    outlineDelay() {
      this.restartAnimations()
    }
  },
  mounted() {
    if (this.paths.length) {
      this.restartAnimations()
    }
  },
  beforeUnmount() {
    this.stopFillAnimation()
    if (this.outlineAnimationTimeout) {
      clearTimeout(this.outlineAnimationTimeout)
      this.outlineAnimationTimeout = null
    }
  },
  methods: {
    restartAnimations() {
      this.stopFillAnimation()
      this.resetOutlineAnimation()
      if (this.outlineAnimationTimeout) {
        clearTimeout(this.outlineAnimationTimeout)
        this.outlineAnimationTimeout = null
      }

      const hasPaths = Array.isArray(this.paths) && this.paths.length > 0
      const target = Math.min(Math.max(this.fillOpacity, 0), 1)

      if (!hasPaths) {
        this.currentFillOpacity = this.pathFill === 'none' ? 0 : target
        this.outlineAnimationStarted = false
        this.outlineAnimationCompleted = false
        const progress =
          target > 0 ? Math.min(this.currentFillOpacity / target, 1) : this.currentFillOpacity > 0 ? 1 : 0
        this.$emit('fill-progress', progress)
        return
      }

      this.currentFillOpacity = 0
      this.$emit('fill-progress', 0)
      this.outlineAnimationStarted = false
      this.outlineAnimationCompleted = false
      this.startOutlineAnimation()
    },
    stopFillAnimation() {
      if (this.fillRafId) {
        cancelAnimationFrame(this.fillRafId)
        this.fillRafId = null
      }
    },
    resetOutlineAnimation() {
      const paths = this.getPathElements()
      paths.forEach((path) => {
        path.style.transition = ''
        path.style.strokeDasharray = ''
        path.style.strokeDashoffset = ''
      })
    },
    getPathElements() {
      const refs = this.$refs.geoPaths
      if (!refs) return []
      if (Array.isArray(refs)) {
        return refs
      }
      return [refs]
    },
    startOutlineAnimation() {
      this.$nextTick(() => {
        const paths = this.getPathElements()
        if (!paths.length) {
          this.outlineAnimationCompleted = true
          this.restartFillAnimation()
          return
        }

        const duration = Math.max(0, this.outlineDuration)
        const delay = Math.max(0, this.outlineDelay)

        paths.forEach((path) => {
          const length = path.getTotalLength()
          path.style.transition = 'none'
          path.style.strokeDasharray = `${length}`
          path.style.strokeDashoffset = `${length}`
        })

        if (paths[0]) {
          void paths[0].getBoundingClientRect()
        }

        paths.forEach((path) => {
          path.style.transition = `stroke-dashoffset ${duration}ms ease ${delay}ms`
          path.style.strokeDashoffset = '0'
        })

        this.outlineAnimationStarted = true

        if (this.outlineAnimationTimeout) {
          clearTimeout(this.outlineAnimationTimeout)
        }
        const totalTime = duration + delay
        this.outlineAnimationTimeout = setTimeout(() => {
          this.outlineAnimationCompleted = true
          this.restartFillAnimation()
        }, totalTime)
      })
    },
    walkCoordinates(geometry, callback) {
      if (!geometry) return
      const { type, coordinates, geometries } = geometry
      switch (type) {
        case 'Point':
          callback(coordinates)
          break
        case 'MultiPoint':
        case 'LineString':
          coordinates.forEach(callback)
          break
        case 'MultiLineString':
          coordinates.forEach((line) => line.forEach(callback))
          break
        case 'Polygon':
          coordinates.forEach((ring) => ring.forEach(callback))
          break
        case 'MultiPolygon':
          coordinates.forEach((polygon) =>
            polygon.forEach((ring) => ring.forEach(callback))
          )
          break
        case 'GeometryCollection':
          geometries.forEach((geom) => this.walkCoordinates(geom, callback))
          break
        default:
          break
      }
    },
    walkPolygons(geometry, callback) {
      if (!geometry) return
      const { type, coordinates, geometries } = geometry
      switch (type) {
        case 'Polygon':
          callback(coordinates)
          break
        case 'MultiPolygon':
          coordinates.forEach((polygon) => callback(polygon))
          break
        case 'GeometryCollection':
          geometries.forEach((geom) => this.walkPolygons(geom, callback))
          break
        default:
          break
      }
    },
    restartFillAnimation() {
      this.stopFillAnimation()

      const hasPaths = Array.isArray(this.paths) && this.paths.length > 0
      const target = Math.min(Math.max(this.fillOpacity, 0), 1)
      const shouldAnimate =
        hasPaths &&
        this.pathFill !== 'none' &&
        target > 0 &&
        typeof window !== 'undefined' &&
        this.outlineAnimationCompleted

      if (!shouldAnimate) {
        this.currentFillOpacity = this.pathFill === 'none' ? 0 : target
        this.fillAnimationStart = null
        const progress =
          target > 0 ? Math.min(this.currentFillOpacity / target, 1) : this.currentFillOpacity > 0 ? 1 : 0
        this.$emit('fill-progress', progress)
        return
      }

      this.currentFillOpacity = 0
      this.fillAnimationStart = null
      this.$emit('fill-progress', 0)
      this.fillRafId = requestAnimationFrame(this.animateFillStep)
    },
    animateFillStep(timestamp) {
      if (this.fillAnimationStart === null) {
        this.fillAnimationStart = timestamp
      }

      const elapsed = timestamp - this.fillAnimationStart
      const duration = Math.max(0, this.fillFadeDuration)
      const target = Math.min(Math.max(this.fillOpacity, 0), 1)

      if (duration === 0) {
        this.currentFillOpacity = target
        const progress = target > 0 ? 1 : 0
        this.$emit('fill-progress', progress)
        this.fillRafId = null
        return
      }

      const progress = Math.min(1, elapsed / duration)
      this.currentFillOpacity = target * progress
      const emittedProgress = target > 0 ? Math.min(this.currentFillOpacity / target, 1) : 0
      this.$emit('fill-progress', emittedProgress)

      if (progress >= 1) {
        this.fillRafId = null
        return
      }

      this.fillRafId = requestAnimationFrame(this.animateFillStep)
    }
  }
}
</script>

<style scoped>
.geojson-viewer {
  width: 100%;
  display: flex;
  justify-content: center;
  align-items: center;
  position: relative;
  padding: 1rem;
  box-sizing: border-box;
}

.geojson-svg {
  width: 100%;
  max-width: 1000px;
  height: auto;
}

.geojson-group {
  transition: transform 600ms ease;
}

.geojson-path {
  transition: fill-opacity 200ms ease, stroke-width 200ms ease;
}

.geojson-path:hover {
  stroke-width: 1.4;
}

.geojson-empty {
  font-size: 1rem;
  color: #6a8574;
  text-align: center;
  padding: 2rem;
}
</style>


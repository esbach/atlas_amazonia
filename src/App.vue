<template>
  <div class="app">
    <header class="header">
      <div class="container">
        <h1
          class="logo"
          role="link"
          tabindex="0"
          @click="goHome"
          @keydown.enter.prevent="goHome"
          @keydown.space.prevent="goHome"
        >
          {{ t.siteTitle }}
        </h1>
        <nav class="nav">
          <a href="#about" @click.prevent="activeSection = 'about'" :class="{ active: activeSection === 'about' }">{{ t.nav.about }}</a>
          <button
            type="button"
            class="icon-button theme-toggle"
            @click="toggleTheme"
            :aria-label="theme === 'dark' ? t.theme.switchToLight : t.theme.switchToDark"
          >
            <span class="sr-only">{{ theme === 'dark' ? t.theme.switchToLight : t.theme.switchToDark }}</span>
            <SunIcon v-if="theme === 'dark'" class="icon theme-icon" aria-hidden="true" />
            <MoonIcon v-else class="icon theme-icon" aria-hidden="true" />
          </button>
          <div
            class="language-menu"
            ref="languageMenu"
            @mouseenter="openLanguageMenu"
            @mouseleave="closeLanguageMenu"
            @focusin="openLanguageMenu"
            @focusout="onLanguageFocusOut"
          >
            <button
              type="button"
              class="icon-button language-toggle"
              @click="toggleLanguageMenu"
              :aria-expanded="isLanguageMenuOpen.toString()"
              :aria-haspopup="'listbox'"
            >
              <span class="language-label">{{ currentLanguageLabel }}</span>
            </button>
            <transition name="fade">
              <ul
                v-if="isLanguageMenuOpen"
                class="language-menu-list"
                role="listbox"
                :aria-activedescendant="`lang-${currentLanguage}`"
              >
                <li v-for="lang in languages" :key="lang.code">
                  <button
                    type="button"
                    :id="`lang-${lang.code}`"
                    class="language-option"
                    :class="{ active: currentLanguage === lang.code }"
                    @click="selectLanguage(lang.code)"
                  >
                    {{ lang.label }}
                  </button>
                </li>
              </ul>
            </transition>
          </div>
        </nav>
      </div>
    </header>

    <main class="main">
      <section v-if="activeSection === 'home'" class="section home-section">
        <div class="image-container">
          <Animation
            v-if="amazonGeoJSON"
            ref="animation"
            :amazonGeoJSON="amazonGeoJSON"
            :width="960"
            :height="600"
            :stroke-color="mapStrokeColor"
            :stroke-width="1.5"
            :fill-color="mapFillColor"
            :fill-opacity="mapFillOpacity"
            :fill-fade-duration="0"
            @fill-progress="onFillProgress"
          />

          <div
            v-if="languageTagline"
            class="geojson-overlay-text"
            :class="{ 'is-visible': isTextVisible, 'no-transition': skipTextTransition }"
            v-html="languageTagline"
          />
          
          <!-- Option 5: Use the static image (uncomment to switch) -->
          <!-- <img :src="imageUrl" :alt="imageAlt" class="main-image" /> -->
        </div>
      </section>

      <section v-if="activeSection === 'about'" class="section about-section">
        <div class="container about-container">
          <h2>{{ t.nav.about }}</h2>
          <p>{{ t.aboutText }}</p>
        </div>
      </section>

    </main>

    <footer class="footer">
      <div class="container footer-content">
        <span class="footer-brand">© 2025 | Amazon Atlas</span>
        <div class="footer-social" role="navigation" aria-label="Footer">
          <a
            href="https://github.com/amazonatlas"
            class="footer-social-link"
            target="_blank"
            rel="noreferrer noopener"
            aria-label="Visit Amazon Atlas on GitHub"
          >
            <span class="sr-only">GitHub</span>
            <svg class="footer-icon" viewBox="0 0 24 24" aria-hidden="true">
              <path
                fill-rule="evenodd"
                clip-rule="evenodd"
                d="M12 2a10 10 0 0 0-3.16 19.48c.5.09.68-.21.68-.47c0-.23-.01-.85-.01-1.67c-2.5.46-3.17-.61-3.37-1.17c-.11-.29-.6-1.17-1.03-1.41c-.35-.19-.85-.66-.01-.67c.78-.01 1.34.72 1.52 1.02c.89 1.5 2.31 1.07 2.88.82c.09-.65.35-1.07.63-1.32c-2.22-.25-4.55-1.11-4.55-4.95c0-1.09.39-1.99 1.03-2.69c-.1-.25-.45-1.27.1-2.65c0 0 .84-.27 2.75 1.02a9.56 9.56 0 0 1 5 0c1.9-1.29 2.74-1.02 2.74-1.02c.55 1.38.2 2.4.1 2.65c.64.7 1.02 1.6 1.02 2.69c0 3.85-2.34 4.7-4.57 4.95c.36.31.68.91.68 1.84c0 1.33-.01 2.4-.01 2.73c0 .26.18.56.69.47A10 10 0 0 0 12 2"
                fill="currentColor"
              />
            </svg>
          </a>
          <a
            href="https://www.linkedin.com/company/amazon-atlas"
            class="footer-social-link"
            target="_blank"
            rel="noreferrer noopener"
            aria-label="Visit Amazon Atlas on LinkedIn"
          >
            <span class="sr-only">LinkedIn</span>
            <svg class="footer-icon" viewBox="0 0 24 24" aria-hidden="true">
              <path
                d="M4.98 3.5a2 2 0 1 1 0 4a2 2 0 0 1 0-4zM3 9h3.96v12H3zM9.75 9H13v1.86h.05c.45-.86 1.56-1.78 3.2-1.78C19.14 9.08 21 10.8 21 14.07V21h-3.96v-6.25c0-1.49-.53-2.5-1.86-2.5c-1.02 0-1.63.69-1.9 1.35c-.1.24-.12.57-.12.9V21H9.75z"
                fill="currentColor"
              />
            </svg>
          </a>
        </div>
      </div>
    </footer>
  </div>
</template>

<script>
import translations from './translations.json'
import Animation from './components/Animation.vue'
import { SunIcon, MoonIcon } from '@heroicons/vue/24/solid'

export default {
  components: {
    Animation,
    SunIcon,
    MoonIcon
  },
  name: 'App',
  data() {
    return {
      currentLanguage: 'en',
      translations: translations,
      activeSection: 'home',
      imageUrl: '/AtlasAmazon.jpg',
      imageAlt: 'Amazon Atlas',
      amazonGeoJSON: null,
      polygonsGeoJSON: null,
      fillProgress: 0,
      isTextVisible: false,
      theme: 'dark',
      isLanguageMenuOpen: false,
      skipTextTransition: false,
      languages: [
        { code: 'en', label: 'EN' },
        { code: 'es', label: 'ES' },
        { code: 'pt', label: 'PT' }
      ],
      textRevealTimeout: null,
      supportsHover: false,
      hoverMediaQuery: null,
      hoverMediaQueryListener: null
    }
  },
  mounted() {
    this.initializeTheme()
    this.evaluateHoverSupport()
    document.addEventListener('click', this.onDocumentClick)
    document.addEventListener('keydown', this.onDocumentKeydown)
    this.loadGeoJSON()
    this.loadPolygonsGeoJSON()
  },
  beforeUnmount() {
    document.removeEventListener('click', this.onDocumentClick)
    document.removeEventListener('keydown', this.onDocumentKeydown)
    this.clearTextRevealTimeout()
    if (this.hoverMediaQuery && this.hoverMediaQueryListener) {
      if (typeof this.hoverMediaQuery.removeEventListener === 'function') {
        this.hoverMediaQuery.removeEventListener('change', this.hoverMediaQueryListener)
      } else if (typeof this.hoverMediaQuery.removeListener === 'function') {
        this.hoverMediaQuery.removeListener(this.hoverMediaQueryListener)
      }
    }
  },
  computed: {
    t() {
      return this.translations[this.currentLanguage] || this.translations.en
    },
    currentYear() {
      return new Date().getFullYear()
    },
    currentLanguageLabel() {
      const active = this.languages.find((lang) => lang.code === this.currentLanguage)
      return active ? active.label : this.currentLanguage.toUpperCase()
    },
    languageTagline() {
      switch (this.currentLanguage) {
        case 'es':
          return 'Conocimiento Colectivo<br />para la Conservación y el Cuidado<br />a través de la Amazonía'
        case 'pt':
          return 'Conhecimento Coletivo<br />para a Conservação e o Cuidado<br />em toda a Amazônia'
        default:
          return 'Collective Knowledge<br />for Conservation and Care<br />across the Amazon'
      }
    },
    mapFillColor() {
      return this.theme === 'dark' ? 'transparent' : '#ffffff'
    },
    mapFillOpacity() {
      return this.theme === 'dark' ? 0 : 1
    },
    mapStrokeColor() {
      return this.theme === 'dark' ? '#ffffff' : '#20412f'
    }
  },
  watch: {
    activeSection(newSection) {
      if (newSection === 'home') {
        this.restartHomeSequence()
      } else {
        this.isTextVisible = false
        this.clearTextRevealTimeout()
      }
    },
    theme(newTheme) {
      this.applyTheme(newTheme)
      if (this.activeSection === 'home') {
        this.restartHomeSequence({ instantTextHide: true })
      }
      try {
        localStorage.setItem('theme', newTheme)
      } catch (error) {
        console.warn('Unable to persist theme preference:', error)
      }
    },
    currentLanguage() {
      this.isLanguageMenuOpen = false
    }
  },
  methods: {
    initializeTheme() {
      let preferredTheme = 'dark'

      try {
        const storedTheme = localStorage.getItem('theme')
        if (storedTheme === 'light' || storedTheme === 'dark') {
          preferredTheme = storedTheme
        }
      } catch (error) {
        console.warn('Unable to read stored theme preference:', error)
      }

      this.theme = preferredTheme
      this.applyTheme(preferredTheme)
    },
    evaluateHoverSupport() {
      if (typeof window === 'undefined' || typeof window.matchMedia !== 'function') {
        this.supportsHover = false
        return
      }

      if (this.hoverMediaQuery && this.hoverMediaQueryListener) {
        if (typeof this.hoverMediaQuery.removeEventListener === 'function') {
          this.hoverMediaQuery.removeEventListener('change', this.hoverMediaQueryListener)
        } else if (typeof this.hoverMediaQuery.removeListener === 'function') {
          this.hoverMediaQuery.removeListener(this.hoverMediaQueryListener)
        }
      }

      const mediaQuery = window.matchMedia('(hover: hover) and (pointer: fine)')
      this.hoverMediaQuery = mediaQuery
      this.supportsHover = mediaQuery.matches

      const handler = (event) => {
        this.supportsHover = event.matches
      }
      this.hoverMediaQueryListener = handler

      if (typeof mediaQuery.addEventListener === 'function') {
        mediaQuery.addEventListener('change', handler)
      } else if (typeof mediaQuery.addListener === 'function') {
        mediaQuery.addListener(handler)
      }
    },
    applyTheme(themeName = this.theme) {
      if (typeof document !== 'undefined') {
        document.body.classList.toggle('theme-dark', themeName === 'dark')
      }
    },
    hideTextInstantly() {
      this.clearTextRevealTimeout()
      this.skipTextTransition = true
      this.isTextVisible = false
      this.$nextTick(() => {
        requestAnimationFrame(() => {
          this.skipTextTransition = false
        })
      })
    },
    toggleTheme() {
      this.theme = this.theme === 'dark' ? 'light' : 'dark'
    },
    async loadGeoJSON() {
      try {
        const response = await fetch('/Amazon.geojson')
        const data = await response.json()
        this.amazonGeoJSON = data
        if (this.activeSection === 'home') {
          this.scheduleTextReveal()
        }
      } catch (error) {
        console.error('Error loading GeoJSON:', error)
      }
    },
    async loadPolygonsGeoJSON() {
      try {
        // Update this path to your polygons GeoJSON file
        // Example: '/polygons.geojson' or '/protected-areas.geojson'
        const response = await fetch('/polygons.geojson')
        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`)
        }
        const data = await response.json()
        this.polygonsGeoJSON = data
      } catch (error) {
        console.error('Error loading polygons GeoJSON:', error)
      }
    },
    onFillProgress(progress) {
      this.fillProgress = Math.min(Math.max(progress, 0), 1)
      if (!this.isTextVisible && this.fillProgress >= 1) {
        this.clearTextRevealTimeout()
        this.isTextVisible = true
      }
    },
    goHome() {
      if (this.activeSection === 'home') {
        this.restartHomeSequence()
      } else {
        this.activeSection = 'home'
      }
    },
    restartHomeSequence({ instantTextHide = false } = {}) {
      if (instantTextHide) {
        this.hideTextInstantly()
      } else {
        this.isTextVisible = false
      }
      this.fillProgress = 0
      this.clearTextRevealTimeout()
      this.$nextTick(() => {
        const animationComponent = this.$refs.animation
        if (animationComponent && typeof animationComponent.restartAnimations === 'function') {
          animationComponent.restartAnimations()
        }
        this.scheduleTextReveal()
      })
    },
    toggleLanguageMenu() {
      this.isLanguageMenuOpen = !this.isLanguageMenuOpen
    },
    openLanguageMenu() {
      if (!this.supportsHover) return
      this.isLanguageMenuOpen = true
    },
    closeLanguageMenu() {
      if (!this.supportsHover) return
      this.isLanguageMenuOpen = false
    },
    onLanguageFocusOut(event) {
      const menu = this.$refs.languageMenu
      if (!menu) return
      const nextFocusTarget = event.relatedTarget
      if (!nextFocusTarget) return
      if (menu.contains(nextFocusTarget)) {
        return
      }
      this.isLanguageMenuOpen = false
    },
    selectLanguage(code) {
      this.currentLanguage = code
      this.isLanguageMenuOpen = false
    },
    onDocumentClick(event) {
      const menu = this.$refs.languageMenu
      if (!menu) return
      if (menu.contains(event.target)) return
      if (this.isLanguageMenuOpen) {
        this.closeLanguageMenu()
      }
    },
    onDocumentKeydown(event) {
      if (event.key === 'Escape' && this.isLanguageMenuOpen) {
        this.isLanguageMenuOpen = false
      }
    },
    scheduleTextReveal() {
      if (this.activeSection !== 'home' || !this.amazonGeoJSON || this.isTextVisible) {
        return
      }

      const animationComponent = this.$refs.animation
      const baseDuration =
        animationComponent && typeof animationComponent.outlineDuration === 'number'
          ? animationComponent.outlineDuration
          : 1800
      const baseDelay =
        animationComponent && typeof animationComponent.outlineDelay === 'number'
          ? animationComponent.outlineDelay
          : 200

      const delay = Math.max(0, baseDuration + baseDelay)

      this.clearTextRevealTimeout()
      this.textRevealTimeout = setTimeout(() => {
        this.isTextVisible = true
        this.textRevealTimeout = null
      }, delay)
    },
    clearTextRevealTimeout() {
      if (this.textRevealTimeout) {
        clearTimeout(this.textRevealTimeout)
        this.textRevealTimeout = null
      }
    }
  }
}
</script>
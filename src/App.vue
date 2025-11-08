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
          <a href="#contact" @click.prevent="activeSection = 'contact'" :class="{ active: activeSection === 'contact' }">{{ t.nav.contact }}</a>
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

      <section v-if="activeSection === 'about'" class="section">
        <div class="container">
          <h2>{{ t.nav.about }}</h2>
          <p>{{ t.aboutText }}</p>
        </div>
      </section>

      <section v-if="activeSection === 'contact'" class="section">
        <div class="container">
          <h2>{{ t.contact.title }}</h2>
          <form @submit.prevent="handleSubmit" class="contact-form">
            <div class="form-group">
              <label for="name">{{ t.contact.name }}</label>
              <input type="text" id="name" v-model="form.name" required>
            </div>
            <div class="form-group">
              <label for="email">{{ t.contact.email }}</label>
              <input type="email" id="email" v-model="form.email" required>
            </div>
            <div class="form-group">
              <label for="message">{{ t.contact.message }}</label>
              <textarea id="message" v-model="form.message" rows="5" required></textarea>
            </div>
            <button type="submit" class="btn">{{ t.contact.sendButton }}</button>
          </form>
          <div v-if="formSubmitted" class="success-message">
            {{ t.contact.successMessage }}
          </div>
        </div>
      </section>
    </main>

    <footer class="footer">
      <div class="container">
        <p>{{ t.footer.replace('{year}', currentYear) }}</p>
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
      theme: 'light',
      isLanguageMenuOpen: false,
      skipTextTransition: false,
      languages: [
        { code: 'en', label: 'EN' },
        { code: 'es', label: 'ES' },
        { code: 'pt', label: 'PT' }
      ],
      form: {
        name: '',
        email: '',
        message: ''
      },
      formSubmitted: false
    }
  },
  mounted() {
    this.initializeTheme()
    document.addEventListener('click', this.onDocumentClick)
    document.addEventListener('keydown', this.onDocumentKeydown)
    this.loadGeoJSON()
    this.loadPolygonsGeoJSON()
  },
  beforeUnmount() {
    document.removeEventListener('click', this.onDocumentClick)
    document.removeEventListener('keydown', this.onDocumentKeydown)
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
      let preferredTheme = 'light'

      try {
        const storedTheme = localStorage.getItem('theme')
        if (storedTheme === 'light' || storedTheme === 'dark') {
          preferredTheme = storedTheme
        } else if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
          preferredTheme = 'dark'
        }
      } catch (error) {
        console.warn('Unable to read stored theme preference:', error)
      }

      this.theme = preferredTheme
      this.applyTheme(preferredTheme)
    },
    applyTheme(themeName = this.theme) {
      if (typeof document !== 'undefined') {
        document.body.classList.toggle('theme-dark', themeName === 'dark')
      }
    },
    hideTextInstantly() {
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
    handleSubmit() {
      // Handle form submission
      console.log('Form submitted:', this.form)
      this.formSubmitted = true
      
      // Reset form after 3 seconds
      setTimeout(() => {
        this.form = {
          name: '',
          email: '',
          message: ''
        }
        this.formSubmitted = false
      }, 3000)
    },
    onFillProgress(progress) {
      this.fillProgress = Math.min(Math.max(progress, 0), 1)
      if (!this.isTextVisible && this.fillProgress >= 1) {
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
      this.$nextTick(() => {
        const animationComponent = this.$refs.animation
        if (animationComponent && typeof animationComponent.restartAnimations === 'function') {
          animationComponent.restartAnimations()
        }
      })
    },
    toggleLanguageMenu() {
      this.isLanguageMenuOpen = !this.isLanguageMenuOpen
    },
    openLanguageMenu() {
      this.isLanguageMenuOpen = true
    },
    closeLanguageMenu() {
      this.isLanguageMenuOpen = false
    },
    onLanguageFocusOut(event) {
      const menu = this.$refs.languageMenu
      if (!menu) return
      if (menu.contains(event.relatedTarget)) {
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
    }
  }
}
</script>
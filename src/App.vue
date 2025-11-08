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
          <div class="language-switcher">
            <button 
              v-for="lang in languages" 
              :key="lang.code"
              @click="currentLanguage = lang.code"
              :class="{ active: currentLanguage === lang.code }"
              class="lang-btn"
            >
              {{ lang.label }}
            </button>
          </div>
        </nav>
      </div>
    </header>

    <main class="main">
      <section v-if="activeSection === 'home'" class="section home-section">
        <div class="image-container">
          <Animation
            v-if="amazonGeoJSON"
            :amazonGeoJSON="amazonGeoJSON"
            :width="960"
            :height="600"
            stroke-color="#20412f"
            :stroke-width="1.5"
            fill-color="#ffffff"
            :fill-opacity="1"
            :fill-fade-duration="0"
            @fill-progress="onFillProgress"
          />

          <div
            v-if="languageTagline"
            class="geojson-overlay-text"
            :class="{ 'is-visible': isTextVisible }"
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

export default {
  components: {
    Animation
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
    this.loadGeoJSON()
    this.loadPolygonsGeoJSON()
  },
  computed: {
    t() {
      return this.translations[this.currentLanguage] || this.translations.en
    },
    currentYear() {
      return new Date().getFullYear()
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
    }
  },
  methods: {
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
      this.activeSection = 'home'
    }
  }
}
</script>
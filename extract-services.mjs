import fs from 'fs'
import yaml from 'js-yaml'

const [,, composePath, outputPath] = process.argv

const compose = yaml.load(fs.readFileSync(composePath, 'utf8'))
const services = {}

for (const [name, config] of Object.entries(compose.services || {})) {
  services[name] = {
    labels: config.labels || {},
    ports: config.ports || []
  }
}

fs.writeFileSync(outputPath, JSON.stringify(services, null, 2))

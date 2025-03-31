import fs from 'fs';
import yaml from 'js-yaml';

const compose = yaml.load(fs.readFileSync('./docker-compose.yml', 'utf8'));
const services = {};

// @ts-ignore
for (const [name, config] of Object.entries(compose.services || {})) {
  services[name] = {
    labels: config.labels || {},
    ports: config.ports || []
  };
}

fs.writeFileSync('./services.json', JSON.stringify(services, null, 2));

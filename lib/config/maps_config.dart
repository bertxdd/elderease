const String geoapifyApiKey = String.fromEnvironment(
  'GEOAPIFY_API_KEY',
  defaultValue: 'de291a4c852741478f4a4e53b2e1108e',
);

const String geoapifyTileUrlTemplate =
    'https://maps.geoapify.com/v1/tile/carto/{z}/{x}/{y}.png?apiKey=$geoapifyApiKey';

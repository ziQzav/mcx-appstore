# Hermes Workspace (Umbrel)
# Secrets derived from umbrelOS app entropy. APP_PASSWORD is the workspace
# login password (also shown in the app's Properties in umbrelOS).
export APP_API_SERVER_KEY=$(derive_entropy "${app_entropy_identifier}-API_SERVER_KEY" | head -c32)
export APP_PASSWORD=$(derive_entropy "${app_entropy_identifier}-APP_PASSWORD" | head -c32)

require "securerandom"
require "base64"
require "net/http"
require "json"
require "openssl"

class QuickbooksOauthService
  DISCOVERY_URLS = {
    "sandbox" => "https://developer.api.intuit.com/.well-known/openid_sandbox_configuration",
    "production" => "https://developer.api.intuit.com/.well-known/openid_configuration"
  }

  def initialize(config: QB_CONFIG)
    @config = config
  end

  def authorization_url
    validate_config!
    discovery = fetch_discovery
    state = generate_state
    scope = @config.scopes.join(" ")

    uri = URI(discovery["authorization_endpoint"])
    params = {
      client_id: @config.client_id,
      response_type: "code",
      scope: scope,
      redirect_uri: @config.dynamic_redirect_uri,
      state: state,
      prompt: "consent"
    }
    uri.query = URI.encode_www_form(params)
    { url: uri.to_s, state: state }
  end

  def exchange_code_for_token(code)
    validate_config!
    discovery = fetch_discovery
    token_uri = URI(discovery["token_endpoint"])

    req = Net::HTTP::Post.new(token_uri)
    req["Content-Type"] = "application/x-www-form-urlencoded"
    req.basic_auth(@config.client_id, @config.client_secret)
    req.set_form_data(
      grant_type: "authorization_code",
      code: code,
      redirect_uri: @config.dynamic_redirect_uri
    )

    res = http_request(token_uri, req)
    JSON.parse(res.body)
  end

  def refresh_token(refresh_token)
    validate_config!
    discovery = fetch_discovery
    token_uri = URI(discovery["token_endpoint"])

    req = Net::HTTP::Post.new(token_uri)
    req["Content-Type"] = "application/x-www-form-urlencoded"
    req.basic_auth(@config.client_id, @config.client_secret)
    req.set_form_data(
      grant_type: "refresh_token",
      refresh_token: refresh_token
    )

    res = http_request(token_uri, req)
    JSON.parse(res.body)
  end

  private

  def http_request(uri, req)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    # Apply SSL settings BEFORE connecting
    if ENV["QB_SSL_INSECURE"] == "1"
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    else
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      cert_store = OpenSSL::X509::Store.new
      cert_store.set_default_paths
      cert_store.flags = 0
      http.cert_store = cert_store
      # Enforce modern TLS
      http.min_version = OpenSSL::SSL::TLS1_2_VERSION if defined?(OpenSSL::SSL::TLS1_2_VERSION)
    end
    res = http.request(req)
    unless res.is_a?(Net::HTTPSuccess)
      raise "OAuth error: #{res.code} #{res.body}"
    end
    res
  end

  def fetch_discovery
    url = DISCOVERY_URLS[@config.environment] || DISCOVERY_URLS["sandbox"]
    uri = URI(url)
    req = Net::HTTP::Get.new(uri)
    res = http_request(uri, req)
    JSON.parse(res.body)
  end

  def generate_state
    Base64.urlsafe_encode64(SecureRandom.random_bytes(32), padding: false)
  end

  def validate_config!
    raise "Client ID missing" if @config.client_id.to_s.strip.empty?
    raise "Client Secret missing" if @config.client_secret.to_s.strip.empty?
    raise "Redirect URI missing" if @config.dynamic_redirect_uri.to_s.strip.empty?
    env = @config.environment
    raise "Environment must be sandbox or production" unless %w[sandbox production].include?(env)
  end
end



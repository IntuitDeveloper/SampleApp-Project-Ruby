class QuickbooksConfig
  attr_accessor :client_id, :client_secret, :redirect_uri, :environment,
                :base_url, :graphql_url, :scopes, :minor_version, :deep_link_template

  def initialize
    @client_id = ENV["QB_CLIENT_ID"]
    @client_secret = ENV["QB_CLIENT_SECRET"]
    @redirect_uri = ENV["QB_REDIRECT_URI"]
    @environment = (ENV["QB_ENVIRONMENT"] || "sandbox").downcase
    @base_url = ENV["QB_BASE_URL"] || "https://quickbooks.api.intuit.com"
    @graphql_url = ENV["QB_GRAPHQL_URL"] || "https://qb.api.intuit.com/graphql"
    @scopes = (ENV["QB_SCOPES"] || "com.intuit.quickbooks.accounting project-management.project").split(/[ ,]+/)
    @minor_version = ENV["QB_MINOR_VERSION"] || "75"
    @deep_link_template = ENV["QB_DEEP_LINK_TEMPLATE"] || "https://app.qbo.intuit.com/app/invoice?txnId=%s&companyId=%s"
  end

  def invoice_deep_link(invoice_id, realm_id)
    raise "Missing deep link template" if @deep_link_template.nil? || @deep_link_template.strip.empty?
    format(@deep_link_template, invoice_id, realm_id)
  end

  def dynamic_redirect_uri
    @redirect_uri
  end
end



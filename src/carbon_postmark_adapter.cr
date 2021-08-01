require "http"
require "json"
require "carbon"

class Carbon::PostmarkAdapter < Carbon::Adapter
  private getter server_token : String

  def initialize(@server_token)
  end

  def deliver_now(email : Carbon::Email)
    Carbon::PostmarkAdapter::Email.new(email, server_token).deliver
  end

  class Email
    BASE_URI           = "api.postmarkapp.com"
    MAIL_SEND_PATH     = "/email"
    TEMPLATE_SEND_PATH = "#{MAIL_SEND_PATH}/withTemplate"
    private getter email, server_token

    def initialize(@email : Carbon::Email, @server_token : String)
    end

    def deliver
      client.post(build_mail_send_path, body: params.to_json).tap do |response|
        raise JSON.parse(response.body).inspect unless response.success?
      end
    end

    def build_mail_send_path
      return TEMPLATE_SEND_PATH if send_template?

      MAIL_SEND_PATH
    end

    def send_template?
      email.headers["TemplateAlias"]? || email.headers["TemplateId"]?
    end

    # Generates params to send to Postmark
    def params
      return build_template_params if send_template?

      build_mail_params
    end

    def build_template_params
      {
        "TemplateId"    => email.headers["TemplateId"]?,
        "TemplateAlias" => email.headers["TemplateAlias"]?,
        "TemplateModel" => build_template_model,
        "InlineCss"     => email.headers["InlineCss"]? || true,
        "From"          => from,
        "To"            => to_postmark_address(email.to),
        "Cc"            => to_postmark_address(email.cc),
        "Bcc"           => to_postmark_address(email.bcc),
        "Tag"           => email.headers["Tag"]?,
        "ReplyTo"       => email.headers["ReplyTo"]?,
        "TrackOpens"    => email.headers["TrackOpens"]?,
        "TrackLinks"    => email.headers["TrackLinks"]?,
        "MessageStream" => email.headers["MessageStream"]?,
      }.reject { |_key, value| !value.is_a?(Bool) && (value.nil? || value.empty?) }
    end

    # Only supports one-level for now
    def build_template_model
      template_model = {} of String => String
      email.headers.each do |key, value|
        if key.starts_with?("TemplateModel:")
          template_model[key.split(':')[1]] = value
        end
      end

      template_model
    end

    def build_mail_params
      {
        "From"          => from,
        "To"            => to_postmark_address(email.to),
        "Cc"            => to_postmark_address(email.cc),
        "Bcc"           => to_postmark_address(email.bcc),
        "Subject"       => email.subject,
        "HtmlBody"      => email.html_body.to_s,
        "TextBody"      => email.text_body.to_s,
        "ReplyTo"       => email.headers["ReplyTo"]?,
        "Tag"           => email.headers["Tag"]?,
        "TrackOpens"    => email.headers["TrackOpens"]?,
        "TrackLinks"    => email.headers["TrackLinks"]?,
        "MessageStream" => email.headers["MessageStream"]?,
      }.reject { |_key, value| value.nil? || value.empty? }
    end

    private def from
      email.from.to_s
    end

    private def to_postmark_address(addresses : Array(Carbon::Address))
      addresses.map(&.to_s)
    end

    @_client : HTTP::Client?

    private def client : HTTP::Client
      @_client ||= HTTP::Client.new(BASE_URI, port: 443, tls: true).tap do |client|
        client.before_request do |request|
          request.headers["Accept"] = "application/json"
          request.headers["Content-Type"] = "application/json"
          request.headers["X-Postmark-Server-Token"] = server_token
        end
      end
    end
  end
end

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

    def params
      (send_template? ? build_template_params : build_mail_params).reject do |_, value|
        !value.is_a?(Bool) && (value.nil? || value.empty?)
      end
    end

    private def build_mail_send_path
      return TEMPLATE_SEND_PATH if send_template?

      MAIL_SEND_PATH
    end

    private def send_template?
      email.headers["TemplateAlias"]? || email.headers["TemplateId"]?
    end

    private def build_template_params
      build_base_mail_params.merge({
        "InlineCss"     => email.headers["InlineCss"]? || true,
        "TemplateAlias" => email.headers["TemplateAlias"]?,
        "TemplateId"    => email.headers["TemplateId"]?,
        "TemplateModel" => build_template_model,
      })
    end

    private def build_mail_params
      build_base_mail_params.merge({
        "HtmlBody" => email.html_body.to_s,
        "Subject"  => email.subject,
        "TextBody" => email.text_body.to_s,
      })
    end

    private def build_base_mail_params
      {
        "Bcc"           => to_postmark_address(email.bcc),
        "Cc"            => to_postmark_address(email.cc),
        "From"          => from,
        "MessageStream" => email.headers["MessageStream"]?,
        "ReplyTo"       => email.headers["ReplyTo"]?,
        "Tag"           => email.headers["Tag"]?,
        "To"            => to_postmark_address(email.to),
        "TrackLinks"    => email.headers["TrackLinks"]?,
        "TrackOpens"    => email.headers["TrackOpens"]?,
      }
    end

    private def build_template_model
      # only supports one-level for now
      ({} of String => String).tap do |hash|
        email.headers.each do |key, value|
          hash[key.split(':')[1]] = value if key.starts_with?("TemplateModel:")
        end
      end
    end

    private def from
      email.from.to_s
    end

    private def to_postmark_address(addresses : Array(Carbon::Address))
      addresses.map(&.address).join(',')
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

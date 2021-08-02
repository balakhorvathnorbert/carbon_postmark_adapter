require "./spec_helper"

describe Carbon::PostmarkAdapter do
  describe "params" do
    it "sets extracts reply-to header" do
      headers = {"ReplyTo" => "noreply@badsupport.com", "Header" => "value"}
      params = params_for(headers: headers)

      params["ReplyTo"].should eq("noreply@badsupport.com")
    end

    it "sets extracts reply-to header regardless of case" do
      headers = {"ReplyTo" => "noreply@badsupport.com", "Header" => "value"}
      params = params_for(headers: headers)

      params["ReplyTo"].should eq("noreply@badsupport.com")
    end

    it "sets the subject" do
      params_for(subject: "My subject")["Subject"].should eq "My subject"
    end

    it "sets the from address" do
      address = Carbon::Address.new("from@example.com")
      params_for(from: address)["From"].should eq("from@example.com")

      address = Carbon::Address.new("Sally", "from@example.com")
      params_for(from: address)["From"].should eq(%("Sally" <from@example.com>))
    end

    it "sets the text body" do
      params_for(text_body: "text")["TextBody"].should eq "text"
    end

    it "sets the html body" do
      params_for(html_body: "html")["HtmlBody"].should eq "html"
    end

    it "strips out empty values" do
      expect_raises(KeyError, %(Missing hash key: "HtmlBody")) do
        params_for(html_body: nil)["HtmlBody"]
      end
    end

    it "adds template model params" do
      headers = {"TemplateId" => "1234", "TemplateModel:someKey" => "someValue"}

      params_for(headers: headers)["TemplateModel"]
        .should eq({"someKey" => "someValue"})
    end
  end
end

private def params_for(**email_attrs)
  email = FakeEmail.new(**email_attrs)
  Carbon::PostmarkAdapter::Email.new(email, server_token: "fake_key").params
end

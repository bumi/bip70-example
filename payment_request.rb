# also have a look at the nice Takecharge Server: https://github.com/controlshift/prague-server and its BOP70 implementation this is based on
class PaymentRequest

  def initialize(options)
    @options = options

    output   = create_output
    details  = create_payment_details(output)

    @payment_request = Payments::PaymentRequest.new
    @payment_request.payment_details_version    = 1
    @payment_request.serialized_payment_details = details.to_s

    @payment_request.pki_type, @payment_request.pki_data = create_pk_infrastructure

    @payment_request.signature = create_signature(@payment_request.to_s)
  end

  def to_s
    @payment_request.to_s
  end

  private

    def create_output
      output = Payments::Output.new
      output.amount = @options[:amount]
      output.script = BTC::Address.parse(@options[:address]).script.data
      output
    end

    def create_payment_details(output)
      payment_details = Payments::PaymentDetails.new
      payment_details.network = @options[:test_mode] ? 'test' : 'main'
      payment_details.time = Time.now.to_i
      payment_details.expires = (Time.now + 3600).to_i
      payment_details.memo = @options[:memo]
      payment_details.payment_url = @options[:payment_url]
      payment_details.merchant_data = @options[:merchant_data]
      payment_details.outputs << output
      payment_details
    end

    def create_pk_infrastructure
      if SIGNED_CERT && !CERT.nil?
        pki_data = create_pki_data
        ['x509+sha256', pki_data.to_s]
      else
        ['none', '']
      end
    end

    def create_pki_data
      pki_data = Payments::X509Certificates.new

      CERT.each_line("-----END CERTIFICATE-----\n") do |cert|
        pki_data.certificate << OpenSSL::X509::Certificate.new(cert).to_der
      end

      pki_data
    end

    def create_signature(data)
      private_key = OpenSSL::PKey::RSA.new(PRIVATE_KEY)
      private_key.sign(OpenSSL::Digest::SHA256.new, data)
    end

end


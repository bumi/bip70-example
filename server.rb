require 'sinatra'
require 'btcruby'
require 'rest-client'
require './payments.pb'
require './payment_request'

# configure your certificate files
CERT        = File.read File.join(File.dirname(__FILE__), 'cert/cert.crt')
PRIVATE_KEY = File.read File.join(File.dirname(__FILE__), 'cert/private.key')
SIGNED_CERT = false # you should get a certificate signed by a accepted root certificate

# /invoice is called by the wallet to receive the Payment Request
# a possible bitcoin URL could be: bitcoin:1D3PknG4Lw1gFuJ9SYenA7pboF9gtXtdcD?amount=100000&r=https://yourdomain.com/invoice
get '/invoice' do
  amount = (params[:amount] || 100000).to_i
  address = params[:address] = '1D3PknG4Lw1gFuJ9SYenA7pboF9gtXtdcD'
  test_mode = !params['test_mode'].nil?
  memo = params[:memo] || 'merchant server says hello'

  # using the PaymentRequest class to create the payment request.
  payment_request = PaymentRequest.new(amount: amount, address: address, test_mode: test_mode, memo: memo, payment_url: 'http://localhost:4567/ack')

  headers['Content-Type'] = 'application/bitcoin-paymentrequest' # set the proper Content-Type, see BIP71
  headers['Content-Disposition'] = 'inline; filename=demo.btcpaymentrequest'
  headers['Content-Transfer-Encoding'] = 'binary'
  headers['Expires'] = '0'
  headers['Cache-Control'] = 'must-revalidate'

  payment_request.to_s
end


# we have passed the URL to /ack in the payment request.
# the wallet will send the payment with its transactions to this URL
# we process/broadcast these transactions and return an ACK
# please not that publishing the transactions does NOT mean they get confirmed you still should make sure that the payment is received
#
# also in this example wo do not do any validation of the transactions. You would want to validate that it fulfills the payment request and sends you the requested amount
post '/ack' do
  request.body.rewind

  # parse the payment from the wallet and get the HEX values of the embedded transactions
  payment = Payments::Payment.parse(request.body.read)
  transactions_hex = payment.transactions.map {|t| t.unpack('H*').first }
  transactions_hex.each do |t|
    r = RestClient.post 'http://tbtc.blockr.io/api/v1/tx/push', hex: t
  end
  #create the ACK and return a nice confirmation message
  ack = Payments::PaymentACK.new
  ack.payment = payment
  ack.memo = 'Thanks, you are awesome. Your payment is processed'

  headers['Content-Type'] = 'application/bitcoin-paymentack' # again set the proper Content-Type
  headers['Content-Disposition'] = "inline; filename=i#{Time.now.to_i}.bitcoinpaymentack"
  headers['Content-Transfer-Encoding'] = 'binary'
  headers['Expires'] = '0'
  headers['Cache-Control'] = 'must-revalidate, post-check=0, pre-check=0'

  ack.to_s
end

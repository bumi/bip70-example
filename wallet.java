// setup a wallet
// example using the WalletAppKit: https://github.com/bitcoinj/bitcoinj/blob/master/examples/src/main/java/org/bitcoinj/examples/Kit.java
NetworkParameters params = TestNet3Params.get();
WalletAppKit kit = new WalletAppKit(params, new File("."), "walletappkit-example"); 
kit.startAsync();
kit.awaitRunning();

// ok let's look at the payment protocol stuff:

// up to you where your app get the URL from. For example from scanning a QR code or when the user clicks on a bitcoin: link and your wallet has registered a protocol handler
String url = "https://example.com/invoice/42"; // or: bitcoin:1LCBEVPm4BpHb89Vv6LKSNE1gaPSsJe7YL?amount=1.42&r=https://example.com/invoice/42

ListenableFuture<PaymentSession> future;

if (url.startsWith("http")) { // if we directly have gotten an URL to a payment request.
  future = PaymentSession.createFromUrl(url);
} else if (url.startsWith("bitcoin:")) {
  future = PaymentSession.createFromBitcoinUri(new BitcoinURI(url)); // getting the payment request URL from bitcoin:..?r=URL 
}

PaymentSession session = future.get(); // bitcoinj requests the URL and parses the payment request which is returned as protocol buffer. see: 

String memoFromMerchant = session.getMemo(); // the message from the merchant. Probably says what your are paying for.
Coin amountToPay = session.getValue(); // the amount you have to pay
PaymentProtocol.PkiVerificationData identity = session.verifyPki(); // botcoinj verifies the request. The merchant has to sign the payment request using a certificate signed from a from the wallet's computer "trusted" root authority
boolean isVerified = identity != null;

System.out.println("Memo: " + memoFromMerchant);
System.out.println("Amount: " + amountToPay.toFriendlyString());
System.out.println("Date: " + session.getDate());
if(isVerified) {
  System.out.println("Verification:");
  System.out.println("Name: " + identity.displayName); // only when the payment request is verified we can display the name to whom we are paying to
  System.out.println("verified by: " + identity.rootAuthorityName); 
}

// payment requests are only valid for a certain amount of time. Don't send money if it is expired
if (session.isExpired()) {
  System.out.println("request is expired!");
} else {
  
  // now the user would have to confirm the transaction.
  
  
  Wallet.SendRequest req = session.getSendRequest(); // get a SendRequest creatin transactions that fulfill the payment request
  kit.wallet().completeTx(req); // adding transaction outputs, sign inputs. see: https://bitcoinj.github.io/javadoc/0.13.5/org/bitcoinj/core/Wallet.html#completeTx-org.bitcoinj.core.Wallet.SendRequest-
  
  String refundAddress = "mjhr9mQqCNpuzcjjFRq71MbUBA9Dv8SoPV"; // we can send a refund address 
  String customerMemo = "thanks for your service"; // and a message to the merchant
  
  ListenableFuture<PaymentProtocol.Ack> paymentFuture = session.sendPayment(req.tx, refundAddress, customerMemo);
  if(future != null) { // null if the merchant has not provided a payment_url that we should send the transactions to
    PaymentProtocol.Ack ack = future.get(); // the ack holds the response from the merchant after posting the payment to the provided payment_url
    kit.wallet().commitTx(req.tx); // commit the transaction, sets the spent flags. see: https://bitcoinj.github.io/javadoc/0.13.5/org/bitcoinj/core/Wallet.html#commitTx-org.bitcoinj.core.Transaction-
    System.out.println("Transaction sent");
    System.out.println("Ack memo from server: " + ack.getMemo()); // the user gets instant feedback about his payment. 
  } else {
    // the merchant has NOT provided a payment_url in the request. which means we simply broadcast the transaction
    Wallet.SendResult sendResult = new Wallet.SendResult();
    sendResult.tx = req.tx;
    sendResult.broadcast = kit.peerGroup().broadcastTransaction(req.tx);
    sendResult.broadcastComplete = sendResult.broadcast.future();
  }
}


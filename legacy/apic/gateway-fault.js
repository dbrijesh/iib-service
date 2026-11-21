// Step 4 (catch). Turns any gateway error into the same SOAP fault shape IIB returns:
// faultcode soapenv:Client or soapenv:Server, detail hpb:Error {Code, Message, CorrelationId}.
var apim = require('apim');

var name = apim.getvariable('error.name') || 'GatewayError';
var status = Number(apim.getvariable('error.status.code')) || 502;
var message = apim.getvariable('error.message') || 'Gateway error';

var codes = {
  RateLimitExceeded: 'HPB-429-RATE-LIMIT',
  HPBChannel: 'HPB-403-CHANNEL',
  InvalidClientId: 'HPB-401-CLIENT',
  ConnectionError: 'HPB-502-GATEWAY',
  OperationError: 'HPB-502-GATEWAY'
};
var code = codes[name] || ('HPB-' + status + '-GATEWAY');
var kind = status >= 500 ? 'Server' : 'Client';
var cid = apim.getvariable('message.headers.x-correlation-id') || apim.getvariable('request.headers.x-global-transaction-id') || '';

function esc(s) { return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;'); }

var body =
  '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:hpb="http://harbourpoint.example/bank/v1">' +
  '<soapenv:Body><soapenv:Fault>' +
  '<faultcode>soapenv:' + kind + '</faultcode><faultstring>' + esc(message) + '</faultstring>' +
  '<detail><hpb:Error><hpb:Code>' + code + '</hpb:Code><hpb:Message>' + esc(message) + '</hpb:Message>' +
  '<hpb:CorrelationId>' + esc(cid) + '</hpb:CorrelationId></hpb:Error></detail>' +
  '</soapenv:Fault></soapenv:Body></soapenv:Envelope>';

apim.setvariable('message.status.code', status);
apim.setvariable('message.headers.content-type', 'text/xml');
session.output.write(body);
apim.output('text/xml');

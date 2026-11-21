// Step 2 of the assembly.
// Copies ChannelId from the calling client app's custom field into the SOAP
// header. Anything the caller put in the header is discarded first, so the
// channel cannot be spoofed. The correlation id is carried in the same header.
var apim = require('apim');

var HPB_NS = 'http://harbourpoint.example/bank/v1';
var VALID = ['MOBILE', 'WEB', 'BRANCH', 'PARTNER'];

var meta = apim.getvariable('client.app.metadata') || {};
var channel = meta.channelId || meta.ChannelId;
if (VALID.indexOf(channel) < 0) {
  apim.error('HPBChannel', 403, 'Forbidden', 'Client app has no valid ChannelId custom field');
}
var correlation = apim.getvariable('message.headers.x-correlation-id') || '';

session.input.readAsBuffer(function (err, buf) {
  if (err) { apim.error('HPBRead', 400, 'Bad Request', 'Cannot read request body'); return; }
  var xml = buf.toString('utf8');

  // drop the caller's whole SOAP header, if any
  xml = xml.replace(/<(\w+:)?Header\b[^>]*\/>/, '')
           .replace(/<(\w+:)?Header\b[^>]*>[\s\S]*?<\/(\w+:)?Header>/, '');

  var header = '<hpb:Header xmlns:hpb="' + HPB_NS + '">' +
               '<hpb:ChannelId>' + channel + '</hpb:ChannelId>' +
               (correlation ? '<hpb:CorrelationId>' + correlation + '</hpb:CorrelationId>' : '') +
               '</hpb:Header>';

  // insert <Header> straight after the Envelope start tag, using its prefix
  xml = xml.replace(/(<((?:\w+:)?)Envelope\b[^>]*>)/, function (all, open, prefix) {
    return open + '<' + prefix + 'Header>' + header + '</' + prefix + 'Header>';
  });

  session.output.write(xml);
  apim.output('text/xml');
});

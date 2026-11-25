/**
 * Familienplaner mail intake.
 *
 * Runs in a family member's own Google account. Every 15 minutes it asks the Familienplaner backend which
 * senders and keywords to look for, searches the mailbox (read-only) and sends sender, subject, date and a
 * link of the matching mails back, together with the mail text (shortened). The server only uses the text to
 * create a suggestion with an AI model; the text itself is not stored.
 *
 * Setup: see README.md. The secret token is stored in the script properties (MAILBOX_TOKEN), never in this file.
 */

var ENDPOINT = 'https://nnqieyhfnmcfyicgdpsp.supabase.co/functions/v1/mail-intake';
var LOOKBACK_DAYS = 3;
var MAX_MESSAGES = 50;
var MAX_SEEN = 300;
var BODY_CHARS = 8000;
var BATCH_SIZE = 10;

/** Run this once by hand: creates the 15-minute trigger and does a first check. */
function install() {
  ScriptApp.getProjectTriggers().forEach(function (trigger) {
    if (trigger.getHandlerFunction() === 'checkMail') {
      ScriptApp.deleteTrigger(trigger);
    }
  });
  ScriptApp.newTrigger('checkMail').timeBased().everyMinutes(15).create();
  checkMail();
}

function checkMail() {
  var token = PropertiesService.getScriptProperties().getProperty('MAILBOX_TOKEN');
  if (!token) {
    throw new Error('MAILBOX_TOKEN fehlt (Projekteinstellungen > Skripteigenschaften).');
  }

  // Asking for the filters also tells the backend that this script is alive.
  var filters = post_({ action: 'filters' }, token);
  var query = buildQuery_(filters);
  if (!query) {
    return;
  }

  var seen = loadSeen_();
  var list = Gmail.Users.Messages.list('me', { q: query, maxResults: MAX_MESSAGES });
  var items = [];
  (list.messages || []).forEach(function (ref) {
    if (seen.indexOf(ref.id) !== -1) {
      return;
    }
    var message = Gmail.Users.Messages.get('me', ref.id, { format: 'full' });
    items.push({
      gmailMessageId: message.id,
      gmailThreadId: message.threadId,
      sender: header_(message, 'From'),
      subject: header_(message, 'Subject'),
      receivedAt: new Date(Number(message.internalDate)).toISOString(),
      link: 'https://mail.google.com/mail/#all/' + message.threadId,
      body: bodyText_(message.payload)
    });
  });

  // Small batches: the server creates one AI suggestion per mail. Only mails the server confirms as handled
  // are remembered, so a mail whose analysis failed is sent again on the next run.
  for (var start = 0; start < items.length; start += BATCH_SIZE) {
    var result = post_({ action: 'items', items: items.slice(start, start + BATCH_SIZE) }, token);
    seen = seen.concat(result.handled || []);
    saveSeen_(seen);
  }
}

/** Plain text of a mail: the text/plain part, or the HTML part without tags. Shortened to BODY_CHARS. */
function bodyText_(payload) {
  var plain = findPart_(payload, 'text/plain');
  var text = plain ? decode_(plain) : '';
  if (!text) {
    var html = findPart_(payload, 'text/html');
    text = html ? decode_(html).replace(/<(style|script)[\s\S]*?<\/\1>/gi, ' ').replace(/<[^>]+>/g, ' ') : '';
  }
  return text.replace(/\s+/g, ' ').trim().slice(0, BODY_CHARS);
}

function findPart_(part, mimeType) {
  if (!part) {
    return null;
  }
  if (part.mimeType === mimeType && part.body && part.body.data) {
    return part;
  }
  var parts = part.parts || [];
  for (var i = 0; i < parts.length; i++) {
    var found = findPart_(parts[i], mimeType);
    if (found) {
      return found;
    }
  }
  return null;
}

/** Gmail sends base64url without padding. Convert to standard base64, pad, decode. Unreadable parts give ''. */
function decode_(part) {
  try {
    var data = String(part.body.data).replace(/-/g, '+').replace(/_/g, '/').replace(/[^A-Za-z0-9+\/]/g, '');
    while (data.length % 4 !== 0) {
      data += '=';
    }
    return Utilities.newBlob(Utilities.base64Decode(data)).getDataAsString('UTF-8');
  } catch (error) {
    console.error('Mailtext konnte nicht gelesen werden: ' + error);
    return '';
  }
}

/** Gmail search: recent mails from any listed sender or containing any listed keyword. */
function buildQuery_(filters) {
  var parts = [];
  (filters.senders || []).forEach(function (sender) {
    var clean = String(sender).replace(/[^A-Za-z0-9@._+-]/g, '');
    if (clean) {
      parts.push('from:' + clean);
    }
  });
  (filters.keywords || []).forEach(function (keyword) {
    var clean = String(keyword).replace(/["{}()\\]/g, '').trim();
    if (clean) {
      parts.push('"' + clean + '"');
    }
  });
  if (parts.length === 0) {
    return '';
  }
  return 'newer_than:' + LOOKBACK_DAYS + 'd -in:spam -in:trash {' + parts.join(' ') + '}';
}

function header_(message, name) {
  var headers = (message.payload && message.payload.headers) || [];
  for (var i = 0; i < headers.length; i++) {
    if (headers[i].name.toLowerCase() === name.toLowerCase()) {
      return headers[i].value;
    }
  }
  return '';
}

function post_(body, token) {
  var response = UrlFetchApp.fetch(ENDPOINT, {
    method: 'post',
    contentType: 'application/json',
    headers: { 'x-mailbox-token': token },
    payload: JSON.stringify(body),
    muteHttpExceptions: true
  });
  if (response.getResponseCode() !== 200) {
    throw new Error('Familienplaner-Server antwortet mit ' + response.getResponseCode());
  }
  return JSON.parse(response.getContentText());
}

function loadSeen_() {
  var raw = PropertiesService.getScriptProperties().getProperty('SEEN');
  return raw ? JSON.parse(raw) : [];
}

function saveSeen_(ids) {
  PropertiesService.getScriptProperties().setProperty('SEEN', JSON.stringify(ids.slice(-MAX_SEEN)));
}

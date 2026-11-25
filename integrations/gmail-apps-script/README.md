# Gmail mail intake (Google Apps Script)

A small script that runs inside a family member's own Google account. It needs no Google Cloud project and
no verification by Google. It only reads mail (`gmail.readonly`), never sends, changes or deletes anything.

Every 15 minutes it:

1. asks the Edge Function `mail-intake` for the sender and keyword filters of this mailbox,
2. searches the last 3 days of mail for matches,
3. sends sender, subject, date, a link and the shortened mail text of new matches to the Edge Function.

The mail text (shortened to 8000 characters) is sent to the Edge Function, which passes it to an AI model to create a suggestion. The text is not stored; only the suggestion, sender, subject, date and link are. The secret token that identifies the mailbox is kept in the
script properties (`MAILBOX_TOKEN`), not in this repository. The database stores only its SHA-256 hash.

Files: `Code.gs` (the script) and `appsscript.json` (permissions and the Gmail service).

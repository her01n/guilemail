## Install

**msmtp** and **fetchmail** executables must be in the PATH.

On Debian:

    # apt install msmtp fetchmail

Running *make* would run some of the unit tests:

    $ make

To test actual send/receive, first create a valid *mail.config* configuration file and run:

    $ make remote-test

Finally install to guile site directory:

    # make install

## API

```
(use-modules (email))
```

- procedure **send-email content [#:to recipient] [#:subject subject] [#:smtp hostname]
    [#:username user] [#:password pass]**

  Send a mail.

  For a plain text email, use *string* content.
  Use *sxml* for *html* emails,
  the mail would be send as a multipart with plain text derived from html.
  
  - **to** recipient address.
  - **subject** optional subject.
  - **smtp** Host name of the SMTP server. The Client would connect to port 465.
  - **username** SMTP username.
  - **password** SMTP password.

- procedure **receive-email [#:to recipient] [#:imap hostname] [#:username user] [#:password pass] **

  Fetch a single unseen mail from the server and mark it as seen.
  If no email is ready on the server, returns *#f*.
  The mail is returned as a string in BSMTP format.

  - **to** If specified ignore mails that are not send to this mail address.
  - **imap** Host name of the IMAP server.
  - **username** IMAP username.
  - **password** IMAP password.

- procedure **mock-email!**

  Enable email mocking.
  *send-email* and *receive-email* will not contact remote servers.
  Any mail sent with *send-email* would be received by *receive-email* directly.

## Configuration

Mail configuration may be saved in a file named **mail.config** in the program working directory.
Caller may now skip this parameters from *send-email* and *receive-email* calls.

Example for gmail:

```
(smtp "smtp.gmail.com")
(imap "imap.gmail.com")
(username "john.smith@gmail.com")
(password "secret")
```

Note if you want to automate gmail,
 you have to enable two factor authentication,
and add an app password.


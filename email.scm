(define-module (email))

(use-modules
  (ice-9 match) (ice-9 popen) (ice-9 textual-ports)
  (srfi srfi-1) (srfi srfi-27)
  (sxml simple))

(define (attribute-ref node key)
  (and (list? node) (list? (cdr node)) (list? (second node))
       (equal? '@ (car (second node)))
       (find identity
             (map (lambda (ls) (and (equal? key (first ls)) (second ls))) (cdr (second node))))))

; Convert sxml content to plain text string
(define (plain-text node)
  (define (follow) (string-concatenate (map plain-text (cdr node))))
  (cond
    ((string? node) node)
    ((or (not (list? node)) (null? node)) "")
    ((equal? '@ (car node)) "")
    ((equal? 'div (car node)) (string-append (follow) "\n"))
    ((equal? 'a (car node)) (string-append (follow) " (" (attribute-ref node 'href) ")"))
    (else (follow))))

(random-source-randomize! default-random-source)

(define (random-string length)
  (apply string-append
    (map
      (lambda (n)
        (let* ((source "abcdefghijklmnopqrstuvxyz0123456789")
               (i (random-integer (string-length source))))
          (substring source i (+ i 1))))
      (iota length))))

(define (sxml? object)
  (and (list? object) (not (null? object)) (symbol? (car object))))

(define* (create-email content #:key to subject)
  (define boundary (random-string 32))
  (call-with-output-string
    (lambda (out)
      (format out "To: ~a\n" to)
      (format out "Subject: ~a\n" subject)
      (format out "MIME-Version: 1.0\n")
      (cond
        ((string? content)
         (format out "Content-Type: text/plain; charset=utf-8\n")
         (format out "\n")
         (format out "~a\n" content))
        ((sxml? content)
         (format out "Content-Type: multipart/alternative; boundary=~a\n" boundary)
         (format out "\n")
         (format out "--~a\n" boundary)
         (format out "Content-Type: text/plain; charset=utf-8\n")
         (format out "\n")
         (format out "~a\n" (plain-text content))
         (format out "\n")
         (format out "--~a\n" boundary)
         (format out "Content-Type: text/html; charset=utf-8\n")
         (format out "\n")
         (sxml->xml content out) (format out "\n")
         (format out "\n")
         (format out "--~a--\n" boundary)
         (format out "\n"))))))

(define (config-ref ref description)
  (define (read-config input)
    (match (read input)
      ((? eof-object? eof) (throw 'missing-config (format #f "Missing ~a" description)))
      ((key value)
       (if (equal? key ref) value (read-config input)))
      (else (read-config input))))
  (call-with-input-file "mail.config" read-config))

(define* (send-real-email email #:key smtp username password)
  (define smtp' (or smtp (config-ref 'smtp "SMTP hostname")))
  (define username' (or username (config-ref 'username "SMTP username")))
  (define password' (or password (config-ref 'password "SMTP password")))
  (call-with-output-file "password"
    (lambda (out)
      (chmod out #o600)
      (put-string out password')))
      (let* ((command
             (format #f
               "msmtp --tls --tls-starttls=off --auth --host=~a --user=~a --from=~a --passwordeval='cat password' --read-recipients"
               smtp' username' username'))
            (pipe (open-output-pipe command)))
       (put-string pipe email)
       (if (not (equal? 0 (status:exit-val (close-pipe pipe))))
           (throw 'mail-error "msmtp failed"))
       (delete-file "password")))

(define-public (mock-email!) (set! mock #t))

(define mock #f)
(define mails '())

(define* (send-email content #:key to subject smtp username password)
  (define email (create-email content #:to to #:subject subject))
  (if mock
      (set! mails (append mails (list email)))
      (send-real-email email #:smtp smtp #:username username #:password password)))

(export send-email)

(define* (receive-mock-email #:key to)
  (define email
    (find
      (lambda (email) (or (not to) (string-contains email (format #f "To: ~a\n" to))))
      mails))
  (if email (set! mails (delete! email mails)))
  email)

(define* (clear-mock-emails #:key to)
  (define to-line (format #f "To: ~a\n" to))
  (set! mails (filter (lambda (email) (and to (not (string-contains email to-line)))) mails)))

(define (call-with-temporary-file-name proc)
  (define name (tmpnam))
  (with-output-to-file name (const #f))
  (call-with-values
    (lambda () (proc name))
    (lambda vals
      (delete-file name)
      (apply values vals))))

(define (execute-fetchmail imap username password commands)
  (define imap' (or imap (config-ref 'imap "IMAP hostname")))
  (define username' (or username (config-ref 'username "IMAP username")))
  (define password' (or password (config-ref 'password "IMAP password")))
  (define fetchmail (open-output-pipe "fetchmail --fetchmailrc -"))
  (format fetchmail "poll \"~a\"\n" imap')
  (format fetchmail "  protocol IMAP,\n")
  (format fetchmail "  user \"~a\",\n" username')
  (format fetchmail "  password \"~a\",\n" password')
  (format fetchmail "  ssl, sslcertck,\n")
  (for-each (lambda (command) (format fetchmail "  ~a,\n" command)) commands)
  (status:exit-val (close-pipe fetchmail)))

(define* (receive-real-email #:key to imap username password)
  (call-with-temporary-file-name
    (lambda (bsmtp)
      (match
        (execute-fetchmail imap username password `("fetchlimit 1" ,(format #f "bsmtp ~a" bsmtp)))
        ; 0 is ok, 13 is MAXFETCH, fetchlimit 1 reached
        ((or 0 13) (call-with-input-file bsmtp get-string-all))
        (1 #f)
        ((? number? n) (throw 'receive-email "Failed to receive email: fetchmail returned ~a" n))
        (#f (throw 'receive-email "Failed to receive email: fetchmail interrupted"))))))

(define* (clear-real-emails #:key to imap username password)
  (match
    (execute-fetchmail imap username password '("bsmtp /dev/null"))
    ((or 0 1) #t)
    (x (throw 'clear-email "Failed to clear emails: ~a" x))))

(define-public (receive-email . args)
  (apply (if mock receive-mock-email receive-real-email) args))

(define-public (clear-emails . args)
  (apply (if mock clear-mock-emails clear-real-emails) args))


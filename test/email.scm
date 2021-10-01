(define-module (test email))

(use-modules
  (hdt hdt)
  (email))

(mock-email!)

(test none
  (assert (not (receive-email))))

(test plain-text
  (send-email "Test plain text content" #:to "chohd8Ul@gmail.com" #:subject "Test Subject")
  (let ((mail (receive-email)))
    (assert (string? mail))
    (assert (string-contains mail "To: chohd8Ul@gmail.com"))
    (assert (string-contains mail "Subject: Test Subject"))
    (assert (string-contains mail "Content-Type: text/plain"))
    (assert (string-contains mail "Test plain text content"))))

(test html
  (send-email '(div "hello " (strong "world!")) #:to "chohd8Ul@gmail.com" #:subject "html test")
  (let ((mail (receive-email)))
    (assert (string? mail))
    (assert (string-contains mail "Content-Type: multipart/alternative"))
    (assert (string-contains mail "Content-Type: text/plain"))
    (assert (string-contains mail "hello world!"))
    (assert (string-contains mail "Content-Type: text/html"))
    (assert (string-contains mail "<div>hello <strong>world!</strong></div>"))))

(test receive-email-to
  (assert (not (receive-email #:to "chohd8Ul@gmail.com")))
  (send-email "test content" #:to "chohd8Ul@gmail.com" #:subject "test")
  (assert (not (receive-email #:to "Ja4aenou@gmail.com")))
  (assert (receive-email #:to "chohd8Ul@gmail.com")))
   
(test clear-emails
  (send-email "test" #:to "chohd8Ul@gmail.com")
  (clear-emails)
  (assert (not (receive-email))))

(test unicode-in-subject
  (send-email "test" #:to "test@example.com" #:subject "čučoriedka")
  (let ((mail (receive-email)))
    (assert (not (string-contains mail "Subject: čučoriedka")))
    (assert (string-contains mail "Subject: =?utf-8?B?xI11xI1vcmllZGth?="))))


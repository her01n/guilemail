(define-module (remote))

(define address "test@sykorka.xyz")

(use-modules (hdt hdt) (email))

(test remote
  (send-email "Test email one, please ignore." #:subject "Test" #:to address)
  (send-email "Test email two, please ignore." #:subject "Test" #:to address)
  (define (check-email email)
    (assert (string-contains email (format #f "To: ~a" address)))
    (assert (string-contains email "Subject: Test"))
    (assert (string-contains email "Test email")))
  (check-email (receive-email))
  (check-email (receive-email)))

(test nomail
  (assert (not (receive-email))))

(test error
  (assert (throws-exception (receive-email #:username "santa.claus"))))


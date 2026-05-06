

Commands

curl
```
curl -I https://sandbox.hiive.dev
    curl: (6) Could not resolve host: sandbox.hiive.dev
```

dig
```
❯ dig sandbox.hiive.dev

; <<>> DiG 9.10.6 <<>> sandbox.hiive.dev
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 32082
;; flags: qr rd ra; QUERY: 1, ANSWER: 0, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;sandbox.hiive.dev.             IN      A
;; Query time: 12 msec                                                                                                                                                                               ;; SERVER: 192.168.1.254#53(192.168.1.254)
;; WHEN: Mon May 04 17:51:40 MDT 2026    
                                                                                                                                                            ;; MSG SIZE  rcvd: 46
```
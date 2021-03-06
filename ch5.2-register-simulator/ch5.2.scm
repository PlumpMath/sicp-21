;;; example
(define gcd-machine
  (make-machine
   '(a b t) ;; register names
   (list (list 'rem remainder) ;; operations
		 (list '= =))
   '(test-b ;; controller instruction sequence
	 (test (op =) (reg b) (const 0))
	 (branch (label gcd-done))
	 (assign t (op rem) (reg a) (reg b))
	 (assign a (reg b))
	 (assign b (reg t))
	 (goto (label test-b))
	 gcd-done)))

#|
  #=> コントローラ命令列を出力させるとこんな感じ
  (list
	(mcons '(test (op =) (reg b) (const 0)) #<procedure:test-proc>)
	(mcons '(branch (label gcd-done)) #<procedure:branch-proc>)
	(mcons '(assign t (op rem) (reg a) (reg b)) #<procedure:assign-proc>)
	(mcons '(assign a (reg b)) #<procedure:assign-proc>)
	(mcons '(assign b (reg t)) #<procedure:assign-proc>)
	(mcons '(goto (label test-b)) #<procedure:goto-proc-1>))
|#

(set-register-contents! gcd-machine 'a 206)
(set-register-contents! gcd-machine 'b 40)
(start gcd-machine)
(get-register-contents gcd-machine 'a) ;;=> 2


;;; factorial machine
(define fact-machine
  (make-machine
   '(val n continue)
   (list (list '= =)
		 (list '- -)
		 (list '* *))
   '(controller
	   (assign continue (label fact-done))
	 fact-loop
	   (test (op =) (reg n) (const 1))
	   (branch (label base-case))
	   (save continue)
	   (save n)
	   (assign n (op -) (reg n) (const 1))
	   (assign continue (label after-fact))
	   (goto (label fact-loop))
	 after-fact
	   (restore n)
	   (restore continue)
	   (assign val (op *) (reg n) (reg val))
	   (goto (reg continue))
	 base-case
	   (assign val (const 1))
	   (goto (reg continue))
	 fact-done)))

(set-register-contents! fact-machine 'n 3)
(fact-machine 'trace-on)
(start fact-machine)
(get-register-contents fact-machine 'val)


;;; apply stack statistics to factorial machine
(define fact-machine
  (make-machine
   '(val n continue)
   (list (list '= =)
		 (list '- -)
		 (list '* *))
   '(controller
	   (perform (op initialize-stack))		 ;; add
	   (assign continue (label fact-done))
	 fact-loop
	   (test (op =) (reg n) (const 1))
	   (branch (label base-case))
	   (save continue)
	   (perform (op print-stack-statistics)) ;; add
	   (save n)
	   (perform (op print-stack-statistics)) ;; add
	   (assign n (op -) (reg n) (const 1))
	   (assign continue (label after-fact))
	   (goto (label fact-loop))
	 after-fact
	   (restore n)
	   (perform (op print-stack-statistics)) ;; add
	   (restore continue)
	   (perform (op print-stack-statistics)) ;; add
	   (assign val (op *) (reg n) (reg val))
	   (goto (reg continue))
	 base-case
	   (assign val (const 1))
	   (goto (reg continue))
	 fact-done)))

(set-register-contents! fact-machine 'n 3)
(start fact-machine)
(get-register-contents fact-machine 'val)


;;; ex 5.14
(define fact-machine
  (make-machine
   '(val n continue)
   (list (list '= =)
		 (list '- -)
		 (list '* *))
   '(controller
	   (perform (op initialize-stack))		 ;; add
	   (assign continue (label fact-done))
	 fact-loop
	   (test (op =) (reg n) (const 1))
	   (branch (label base-case))
	   (save continue)
	   (save n)
	   (assign n (op -) (reg n) (const 1))
	   (assign continue (label after-fact))
	   (goto (label fact-loop))
	 after-fact
	   (restore n)
	   (restore continue)
	   (assign val (op *) (reg n) (reg val))
	   (goto (reg continue))
	 base-case
	   (perform (op print-stack-statistics)) ;; add
	   (assign val (const 1))
	   (goto (reg continue))
	 fact-done)))

(map (lambda (n)
	   (set-register-contents! fact-machine 'n n)
	   (start fact-machine))
	 '(1 2 3 4 5 6 7 8 9 10))

;; =>
;; '(total-pushes = 0 max-depth = 0 curr-depth = 0)
;; '(total-pushes = 2 max-depth = 2 curr-depth = 2)
;; '(total-pushes = 4 max-depth = 4 curr-depth = 4)
;; '(total-pushes = 6 max-depth = 6 curr-depth = 6)
;; '(total-pushes = 8 max-depth = 8 curr-depth = 8)
;; '(total-pushes = 10 max-depth = 10 curr-depth = 10)
;; '(total-pushes = 12 max-depth = 12 curr-depth = 12)
;; '(total-pushes = 14 max-depth = 14 curr-depth = 14)
;; '(total-pushes = 16 max-depth = 16 curr-depth = 16)
;; '(total-pushes = 18 max-depth = 18 curr-depth = 18)
;; '(done done done done done done done done done done)


;;; ex 5.15

#|
diff --git a/ch5-register-simulator/regsim.scm b/ch5-register-simulator/regsim.scm
index 148ddb5..e475d4a 100644
--- a/ch5-register-simulator/regsim.scm
+++ b/ch5-register-simulator/regsim.scm
@@ -21,6 +21,7 @@
		 (flag (make-register 'flag))
		 (stack (make-stack))
		 (the-instruction-sequence '())
		 (the-ops (list (list 'initialize-stack
							  (lambda () (stack 'initialize)))
						(list 'print-stack-statistics
		 (register-table (list (list 'pc pc)
-							   (list 'flag flag))))
+							   (list 'flag flag)))
+		 (instruction-count 0))
@@ -45,6 +46,7 @@
			'done
			(begin
			  ((instruction-execution-proc (car insts)))
+			  (set! instruction-count (+ instruction-count 1))
			  (execute)))))
	(define (dispatch message)
	  (cond ((eq? message 'start)
@@ -53,6 +55,10 @@
			((eq? message 'install-instruction-sequence)
			 (lambda (seq)
			   (set! the-instruction-sequence seq)))
+			((eq? message 'initialize-instruction-count)
+			 (set! instruction-count 0))
+			((eq? message 'get-instruction-count)
+			 instruction-count)
			((eq? message 'allocate-register)
			 allocate-register)
			((eq? message 'get-register)
|#

(map (lambda (n)
	   (set-register-contents! fact-machine 'n n)
	   (fact-machine 'initialize-instruction-count)
	   (start fact-machine)
	   (pretty-print (list 'n '= n
						   'instruction-count '=
						   (fact-machine 'get-instruction-count))))
	 '(1 2 3 4 5 6 7 8 9 10))

;;=>
;; '(n = 1 instruction-count = 5)
;; '(n = 2 instruction-count = 16)
;; '(n = 3 instruction-count = 27)
;; '(n = 4 instruction-count = 38)
;; '(n = 5 instruction-count = 49)
;; '(n = 6 instruction-count = 60)
;; '(n = 7 instruction-count = 71)
;; '(n = 8 instruction-count = 82)
;; '(n = 9 instruction-count = 93)
;; '(n = 10 instruction-count = 104)


;;; ex 5.16

#|
diff --git a/ch5-register-simulator/regsim.scm b/ch5-register-simulator/regsim.scm
index 148ddb5..3732668 100644
--- a/ch5-register-simulator/regsim.scm
+++ b/ch5-register-simulator/regsim.scm
@@ -21,6 +21,8 @@
		 (flag (make-register 'flag))
		 (stack (make-stack))
		 (the-instruction-sequence '())
		 (the-ops (list (list 'initialize-stack
							  (lambda () (stack 'initialize)))
						(list 'print-stack-statistics
		 (register-table (list (list 'pc pc)
							   (list 'flag flag)))
-		 (instruction-count 0))
+		 (instruction-count 0)
+		 (trace-flag false))
@@ -44,7 +46,12 @@
		(if (null? insts)
			'done
			(begin
-			  ((instruction-execution-proc (car insts)))
+			  (let ((inst (car insts)))
+				(if trace-flag
+					(pretty-print (list 'inst '= (instruction-text inst)))
+					false)
+				((instruction-execution-proc inst)))
			  (set! instruction-count (+ instruction-count 1))
			  (execute)))))
	(define (dispatch message)
	  (cond ((eq? message 'start)
@@ -53,6 +60,14 @@
			((eq? message 'install-instruction-sequence)
			 (lambda (seq)
			   (set! the-instruction-sequence seq)))
			((eq? message 'initialize-instruction-count)
			 (set! instruction-count 0))
			((eq? message 'get-instruction-count)
			 instruction-count)
+			((eq? message 'trace-on)
+			 (set! trace-flag true))
+			((eq? message 'trace-off)
+			 (set! trace-flag false))
			((eq? message 'allocate-register)
			 allocate-register)
			((eq? message 'get-register)
|#

(fact-machine 'trace-on)
(set-register-contents! fact-machine 'n 3)
(start fact-machine)

#|
;;=>

'(inst = (assign continue (label fact-done)))
'(inst = (test (op =) (reg n) (const 1)))
'(inst = (branch (label base-case)))
'(inst = (save continue))
'(inst = (save n))
'(inst = (assign n (op -) (reg n) (const 1)))
'(inst = (assign continue (label after-fact)))
'(inst = (goto (label fact-loop)))
'(inst = (test (op =) (reg n) (const 1)))
'(inst = (branch (label base-case)))
'(inst = (save continue))
'(inst = (save n))
'(inst = (assign n (op -) (reg n) (const 1)))
'(inst = (assign continue (label after-fact)))
'(inst = (goto (label fact-loop)))
'(inst = (test (op =) (reg n) (const 1)))
'(inst = (branch (label base-case)))
'(inst = (assign val (const 1)))
'(inst = (goto (reg continue)))
'(inst = (restore n))
'(inst = (restore continue))
'(inst = (assign val (op *) (reg n) (reg val)))
'(inst = (goto (reg continue)))
'(inst = (restore n))
'(inst = (restore continue))
'(inst = (assign val (op *) (reg n) (reg val)))
'(inst = (goto (reg continue)))
'done
|#


;;; ex 5.17

#|
index f76d736..1f801f6 100644
--- a/ch5-register-simulator/regsim.scm
+++ b/ch5-register-simulator/regsim.scm
@@ -11,7 +11,7 @@
(define (make-machine register-names ops ctrl-text)
  (let ((machine (make-new-machine)))
	;; レジスタの登録
	(for-each (lambda (register-name)
				((machine 'allocate-register) register-name))
			  register-names)
	;; オペレーションの登録
	((machine 'install-operations) ops)
	;; 命令シーケンスの登録
	(let ((inst-seq (assemble ctrl-text machine)))
	  (pretty-print inst-seq)	;; 命令シーケンスの登録
	(let ((inst-seq (assemble ctrl-text machine)))
	  (pretty-print inst-seq)
-	  ((machine 'install-instruction-sequence) inst-seq))
+	  ((machine 'install-instruction-sequence) (cons (car ctrl-text) inst-seq)))
	machine))


@@ -45,14 +45,21 @@
	(define (execute)
	  (let ((insts (get-contents pc)))
		(if (null? insts)
			'done
-			(begin
-			  (let ((inst (car insts)))
-				(if trace-flag
-					(pretty-print (list 'inst '= (instruction-text inst)))
-					false)
-				((instruction-execution-proc inst)))
-			  (set! instruction-count (+ instruction-count 1))
-			  (execute)))))
+			(if (symbol? (car insts))
+				(begin
+				  (if trace-flag
+					  (pretty-print (list 'label '= (car insts)))
+					  false)
+				  (set-contents! pc (cdr insts))
+				  (execute))
+				(begin
+				  (let ((inst (car insts)))
+					(if trace-flag
+						(pretty-print (list 'inst '= (instruction-text inst)))
+						false)
+					((instruction-execution-proc inst)))
+				  (set! instruction-count (+ instruction-count 1))
+				  (execute))))))
	(define (dispatch message)
	  (cond ((eq? message 'start)
			 (set-contents! pc the-instruction-sequence)
@@ -173,7 +180,8 @@
(define (extract-labels ctrl-text recieve)
  (if (null? ctrl-text)
	  (recieve '() '())
	  (extract-labels (cdr ctrl-text)
					  (lambda (insts labels)
						(let ((next-inst (car ctrl-text)))
						  (if (symbol? next-inst)
							  (if (label-insts labels next-inst)
								  (error "[extract-labels] duplicate label:" next-inst)
								  (recieve insts
-										   (cons (make-label-entry next-inst insts)
+										   (cons (make-label-entry next-inst
+																   (cons next-inst insts))
												 labels)))
							  (recieve (cons (make-instruction next-inst)
											 insts)
									   labels)))))))
|#

(set-register-contents! fact-machine 'n 3)
(fact-machine 'trace-on)
(start fact-machine)

#|
;;=>

'(inst = (assign continue (label fact-done)))
'(inst = (test (op =) (reg n) (const 1)))
'(inst = (branch (label base-case)))
'(inst = (save continue))
'(inst = (save n))
'(inst = (assign n (op -) (reg n) (const 1)))
'(inst = (assign continue (label after-fact)))
'(inst = (goto (label fact-loop)))
'(label = fact-loop)
'(inst = (test (op =) (reg n) (const 1)))
'(inst = (branch (label base-case)))
'(inst = (save continue))
'(inst = (save n))
'(inst = (assign n (op -) (reg n) (const 1)))
'(inst = (assign continue (label after-fact)))
'(inst = (goto (label fact-loop)))
'(label = fact-loop)
'(inst = (test (op =) (reg n) (const 1)))
'(inst = (branch (label base-case)))
'(label = base-case)
'(inst = (assign val (const 1)))
'(inst = (goto (reg continue)))
'(label = after-fact)
'(inst = (restore n))
'(inst = (restore continue))
'(inst = (assign val (op *) (reg n) (reg val)))
'(inst = (goto (reg continue)))
'(label = after-fact)
'(inst = (restore n))
'(inst = (restore continue))
'(inst = (assign val (op *) (reg n) (reg val)))
'(inst = (goto (reg continue)))
'(label = fact-done)
'done
|#


;;; ex 5.18

#|
diff --git a/ch5-register-simulator/regsim.scm b/ch5-register-simulator/regsim.scm
index 03f8021..fb0c4e6 100644
--- a/ch5-register-simulator/regsim.scm
+++ b/ch5-register-simulator/regsim.scm
@@ -79,6 +79,12 @@
			 allocate-register)
			((eq? message 'get-register)
			 lookup-register)
+			((eq? message 'trace-register-on)
+			 (lambda (reg-name)
+			   ((lookup-register reg-name) 'trace-on)))
+			((eq? message 'trace-register-off)
+			 (lambda (reg-name)
+			   ((lookup-register reg-name) 'trace-off)))
			((eq? message 'install-operations)
			 (lambda (ops)
			   (set! the-ops (append the-ops ops))))
@@ -103,12 +109,22 @@
 
 ;;;; register
 (define (make-register name)
-  (let ((contents '*unassigned*))
+  (let ((contents '*unassigned*)
+		(trace-flag false))
	(define (dispatch message)
	  (cond ((eq? message 'get)
			 contents)
			((eq? message 'set)
-			 (lambda (value) (set! contents value)))
+			 (lambda (value)
+			   (if trace-flag
+				   (pretty-print (list 'reg '= name ':
+									   contents '=> value))
+				   false)
+			   (set! contents value)))
+			((eq? message 'trace-on)
+			 (set! trace-flag true))
+			((eq? message 'trace-off)
+			 (set! trace-flag false))
			(else
			 (error "[register] unknown request:" message))))
	dispatch))
|#

(set-register-contents! fact-machine 'n 3)
((fact-machine 'trace-register-on) 'val)
(start fact-machine)

#|
;;=>

'(reg = val : *unassigned* => 1)
'(reg = val : 1 => 2)
'(reg = val : 2 => 6)
'done
|#


;;; ex 5.19

#|

```diff
 (define (make-new-machine)
   (let* ((pc (make-register 'pc))
		 (flag (make-register 'flag))
		 (stack (make-stack))
		 (the-instruction-sequence '())
		 (the-ops (list (list 'initialize-stack
							  (lambda () (stack 'initialize)))
						(list 'print-stack-statistics
							  (lambda () (stack 'print-statistics)))))
		 (register-table (list (list 'pc pc)
							   (list 'flag flag)))
		 (instruction-count 0)
-		 (trace-flag false))
+		 (trace-flag false)
+		 (the-breakpoints '()))
```

```diff
+			((eq? message 'set-breakpoint)
+			 (lambda (label-name line-number)
+			   (set! the-breakpoints
+					 (cons (cons label-name line-number) the-breakpoints))))
+			((eq? message 'cancel-breakpoint)
+			 (lambda (label-name line-number)
+			   (set! the-breakpoints
+					 (filter (lambda (item)
+							   (not (equal? item (cons label-name line-number))))
+							 the-breakpoints))))
+			((eq? message 'cancel-all-breakpoints)
+			 (set! the-breakpoints '()))
+			((eq? message 'print-breakpoints)
+			 (pretty-print (list 'breakpoints '= the-breakpoints)))
			(else
			 (error "[machine] unknown request:" message))))
	dispatch))
```

```diff
 (define (make-new-machine)
   (let* ((pc (make-register 'pc))
		 (flag (make-register 'flag))
		 (stack (make-stack))
		 (the-instruction-sequence '())
		 (the-ops (list (list 'initialize-stack
							  (lambda () (stack 'initialize)))
						(list 'print-stack-statistics
							  (lambda () (stack 'print-statistics)))))
		 (register-table (list (list 'pc pc)
							   (list 'flag flag)))
		 (instruction-count 0)
		 (trace-flag false)
-		 (the-breakpoints '()))
+		 (the-breakpoints '())
+		 (current-point '()))
```

```diff
	(define (execute)
	  (let ((insts (get-contents pc)))
		(if (null? insts)
			'done
			(if (symbol? (car insts))
				(begin
				  (if trace-flag
					  (pretty-print (list 'label '= (car insts)))
					  false)
+				  (set! current-point (cons (car insts) 0))
				  (set-contents! pc (cdr insts))
				  (execute))
				(begin
				  (let ((inst (car insts)))
					(if trace-flag
						(pretty-print (list 'inst '= (instruction-text inst)))
						false)
					((instruction-execution-proc inst)))
				  (set! instruction-count (+ instruction-count 1))
-				  (execute))))))
+				  (set! current-point (cons (car current-point)
+											(add1 (cdr current-point))))
+				  (if (member current-point the-breakpoints)
+					  'break!
+					  (execute)))))))

```

```diff
+			((eq? message 'proceed)
+			 (execute))
			(else
			 (error "[machine] unknown request:" message))))
	dispatch))
```

```diff
+(define (set-breakpoint machine label-name line-number)
+  ((machine 'set-breakpoint) label-name line-number))
+(define (cancel-breakpoint machine label-name line-number)
+  ((machine 'cancel-breakpoint) label-name line-number))
+(define (cancel-all-breakpoints machine)
+  (machine 'cancel-all-breakpoints))
+(define (proceed-machine machine)
+  (machine 'proceed))
```
|#

(define gcd-machine
  (make-machine
   '(a b t)
   (list (list 'rem remainder) (list '= =))
   '(test-b
	   (test (op =) (reg b) (const 0))
	   (branch (label gcd-done))
	   (assign t (op rem) (reg a) (reg b))
	   (assign a (reg b))
	   (assign b (reg t))
	   (goto (label test-b))
	   gcd-done)))

(set-register-contents! gcd-machine 'a 206)
(set-register-contents! gcd-machine 'b 40)
(set-breakpoint gcd-machine 'test-b 4)
(start gcd-machine)

#|
regsim.scm﻿> (start gcd-machine)
'break!
regsim.scm﻿> (get-register-contents gcd-machine 'a)
40
regsim.scm﻿> (proceed-machine gcd-machine)
'break!
regsim.scm﻿> (get-register-contents gcd-machine 'a)
6
regsim.scm﻿> (proceed-machine gcd-machine)
'break!
regsim.scm﻿> (get-register-contents gcd-machine 'a)
4
regsim.scm﻿> (proceed-machine gcd-machine)
'break!
regsim.scm﻿> (get-register-contents gcd-machine 'a)
2
regsim.scm﻿> (proceed-machine gcd-machine)
'done
regsim.scm﻿> (get-register-contents gcd-machine 'a)
2
|#

;;;; SICP Chapter 5.2
;;;; A Register-Machine Simulator
;;;;
;;;; Author @uents on twitter
;;;;

#| example

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

(start gcd-machine)

(get-register-contents gcd-machine 'a)

|#

#lang racket

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
	  (pretty-print inst-seq)
	  ((machine 'install-instruction-sequence) (cons (car ctrl-text) inst-seq)))
	machine))


;;;; basical machine
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
		 (the-breakpoints '())
		 (current-point '()))
	(define (allocate-register name)
	  (if (assoc name register-table)
		  (error "[machine] multiply defined register: " name)
		  (set! register-table
				(cons (list name (make-register name))
					  register-table)))
	  'register-allocated)
	(define (lookup-register name)
	  (let ((val (assoc name register-table)))
		(if val
			(cadr val)
			(error "[machine] unknown register: " name))))
	(define (execute)
	  (let ((insts (get-contents pc)))
		(if (null? insts)
			'done
			(if (symbol? (car insts))
				(begin
				  (if trace-flag
					  (pretty-print (list 'label '= (car insts)))
					  false)
				  (set! current-point (cons (car insts) 0))
				  (set-contents! pc (cdr insts))
				  (execute))
				(begin
				  (let ((inst (car insts)))
					(if trace-flag
						(pretty-print (list 'inst '= (instruction-text inst)))
						false)
					((instruction-execution-proc inst)))
				  (set! instruction-count (+ instruction-count 1))
				  (set! current-point (cons (car current-point)
											(add1 (cdr current-point))))
				  (if (member current-point the-breakpoints)
					  'break!
					  (execute)))))))
	(define (dispatch message)
	  (cond ((eq? message 'start)
			 (set-contents! pc the-instruction-sequence)
			 (execute))
			((eq? message 'install-instruction-sequence)
			 (lambda (seq)
			   (set! the-instruction-sequence seq)))
			((eq? message 'allocate-register)
			 allocate-register)
			((eq? message 'get-register)
			 lookup-register)
			((eq? message 'install-operations)
			 (lambda (ops)
			   (set! the-ops (append the-ops ops))))
			((eq? message 'stack)
			 stack)
			((eq? message 'operations)
			 the-ops)
			((eq? message 'initialize-instruction-count)
			 (set! instruction-count 0))
			((eq? message 'get-instruction-count)
			 instruction-count)
			((eq? message 'trace-on)
			 (set! trace-flag true))
			((eq? message 'trace-off)
			 (set! trace-flag false))
			((eq? message 'trace-register-on)
			 (lambda (reg-name)
			   ((lookup-register reg-name) 'trace-on)))
			((eq? message 'trace-register-off)
			 (lambda (reg-name)
			   ((lookup-register reg-name) 'trace-off)))
			((eq? message 'set-breakpoint)
			 (lambda (label-name line-number)
			   (set! the-breakpoints
					 (cons (cons label-name line-number) the-breakpoints))))
			((eq? message 'cancel-breakpoint)
			 (lambda (label-name line-number)
			   (set! the-breakpoints
					 (filter (lambda (item)
							   (not (equal? item (cons label-name line-number))))
							 the-breakpoints))))
			((eq? message 'cancel-all-breakpoints)
			 (set! the-breakpoints '()))
			((eq? message 'print-breakpoints)
			 (pretty-print (list 'breakpoints '= the-breakpoints)))
			((eq? message 'proceed)
			 (execute))
			(else
			 (error "[machine] unknown request:" message))))
	dispatch))

(define (start machine)
  (machine 'start))
(define (get-register machine reg-name)
  ((machine 'get-register) reg-name))
(define (get-register-contents machine reg-name)
  (get-contents (get-register machine reg-name)))
(define (set-register-contents! machine reg-name value)
  (set-contents! (get-register machine reg-name) value)
  'done)
(define (set-breakpoint machine label-name line-number)
  ((machine 'set-breakpoint) label-name line-number))
(define (cancel-breakpoint machine label-name line-number)
  ((machine 'cancel-breakpoint) label-name line-number))
(define (cancel-all-breakpoints machine)
  (machine 'cancel-all-breakpoints))
(define (proceed-machine machine)
  (machine 'proceed))

;;;; register
(define (make-register name)
  (let ((contents '*unassigned*)
		(trace-flag false))
	(define (dispatch message)
	  (cond ((eq? message 'get)
			 contents)
			((eq? message 'set)
			 (lambda (value)
			   (if trace-flag
				   (pretty-print (list 'reg '= name ':
									   contents '=> value))
				   false)
			   (set! contents value)))
			((eq? message 'trace-on)
			 (set! trace-flag true))
			((eq? message 'trace-off)
			 (set! trace-flag false))
			(else
			 (error "[register] unknown request:" message))))
	dispatch))

(define (get-contents register) (register 'get))
(define (set-contents! register value) ((register 'set) value))

;;;; stack
(define (make-stack)
  (let ((s '())
		(number-pushes 0)
		(max-depth 0)
		(current-depth 0))
	(define (push x)
	  (set! s (cons x s))
	  (set! number-pushes (+ 1 number-pushes))
	  (set! current-depth (+ 1 current-depth))
	  (set! max-depth (max current-depth max-depth)))
	(define (pop)
	  (if (null? s)
		  (error "[stack] empty stack")
		  (let ((top (car s)))
			(set! s (cdr s))
			(set! current-depth (- current-depth 1))
			top)))
	(define (initialize)
	  (set! s '())
	  (set! number-pushes 0)
	  (set! max-depth 0)
	  (set! current-depth 0)
	  'done)
	(define (print-statistics)
	  (pretty-print (list 'total-pushes '= number-pushes
						  'max-depth '= max-depth
						  'curr-depth '= current-depth)))

	;; pushは内部手続きを返すが、
	;; pop/initializeは内部手続きの実行して結果を返す(ややこしい..)
	(define (dispatch message)
	  (cond ((eq? message 'push) push)
			((eq? message 'pop) (pop))
			((eq? message 'initialize) (initialize))
			((eq? message 'print-statistics) (print-statistics))
			(else
			 (error "[stack] unknown request:" + message))))
	dispatch))

(define (push stack value) ((stack 'push) value))
(define (pop stack) (stack 'pop))


;;;; assembler
;;;; 命令テキストを実行手続きシーケンスに変換
(define (assemble ctrl-text machine)
  (extract-labels ctrl-text
				  (lambda (insts labels)
					(update-insts! insts labels machine)
					insts)))

;;; 命令テキストを展開してlabels、instsにpushする
;;; textは命令式の列、recieve 継続処理
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
										   (cons (make-label-entry next-inst
																   (cons next-inst insts))
												 labels)))
							  (recieve (cons (make-instruction next-inst)
											 insts)
									   labels)))))))

(define (update-insts! insts labels machine)
  (let ((pc (get-register machine 'pc))
		(flag (get-register machine 'flag))
		(stack (machine 'stack))
		(ops (machine 'operations)))
	(for-each
	 (lambda (inst)
	   (set-instruction-execution-proc!
		inst
		(make-execution-procedure
		 (instruction-text inst)
		 labels machine pc flag stack ops)))
	 insts)))


;;; instrcution
;;; - text(テキスト)とexecution-proc(実行手続き)の対
;;; - textはシミュレータでは使用されないがデバッグで使える(ex 5.16)
(define (make-instruction text)
  (mcons text '()))
(define (instruction-text inst)
  (mcar inst))
(define (instruction-execution-proc inst)
  (mcdr inst))
(define (set-instruction-execution-proc! inst proc)
  (set-mcdr! inst proc))


;;; label table
;;; - テーブルの要素はラベル名と命令データの対
(define (make-label-entry label-name insts)
  (cons label-name insts))

(define (label-insts labels label-name)
  (assoc label-name labels))

(define (lookup-label labels label-name)
  (let ((val (label-insts labels label-name)))
	(if val
		(cdr val)
		(error "[lookup-label] undefined label:" label-name))))

;;; 実行手続きの生成
(define (make-execution-procedure
		 inst labels machine pc flag stack ops)
  (cond ((eq? (car inst) 'assign)
		 (make-assign inst machine labels ops pc))
		((eq? (car inst) 'test)
		 (make-test inst machine labels ops flag pc))
		((eq? (car inst) 'branch)
		 (make-branch inst machine labels flag pc))
		((eq? (car inst) 'goto)
		 (make-goto inst machine labels pc))
		((eq? (car inst) 'save)
		 (make-save inst machine stack pc))
		((eq? (car inst) 'restore)
		 (make-restore inst machine stack pc))
		((eq? (car inst) 'perform)
		 (make-perform inst machine labels ops pc))
		(else
		 (error "[make-execution-procedure] unknown type:" inst))))

(define (advance-pc pc)
  (set-contents! pc (cdr (get-contents pc))))

;;; assign
(define (make-assign inst machine labels ops pc)
  (let* ((target (get-register machine (assign-reg-name inst)))
		 (value-exp (assign-value-exp inst))
		 (value-proc (if (operation-exp? value-exp)
						 (make-operation-exp value-exp machine labels ops)
						 (make-primitive-exp (car value-exp) machine labels))))
	(define (assign-proc)
	  (set-contents! target (value-proc))
	  (advance-pc pc))
	assign-proc))

(define (assign-reg-name inst) (cadr inst))
(define (assign-value-exp inst) (cddr inst))

;;; test
(define (make-test inst machine labels ops flag pc)
  (let ((condition (test-condition inst)))
	(if (operation-exp? condition)
		(let ((condition-proc (make-operation-exp
							   condition machine labels ops)))
		  (define (test-proc)
			(set-contents! flag (condition-proc))
			(advance-pc pc))
		  test-proc)
		(error "[make-test] bad test instruction:" inst))))

(define (test-condition inst) (cdr inst))

;;; branch
(define (make-branch inst machine labels flag pc)
  (let ((dest (branch-dest inst)))
	(if (label-exp? dest)
		(let ((insts (lookup-label labels
								   (label-exp-label dest))))
		  (define (branch-proc)
			(if (get-contents flag)
				(set-contents! pc insts)
				(advance-pc pc)))
		  branch-proc)
		(error "[make-branch] bad branch instruction:" inst))))

(define (branch-dest inst) (cadr inst))

;;; goto
(define (make-goto inst machine labels pc)
  (let ((dest (goto-dest inst)))
	(cond ((label-exp? dest) ;; for (goto (label xx))
		   (let ((insts (lookup-label labels
									  (label-exp-label dest))))
			 (define (goto-label-proc)
			   (set-contents! pc insts))
			 goto-label-proc))
		  ((register-exp? dest) ;; for (goto (reg xx))
		   (let ((reg (get-register machine
									(register-exp-reg dest))))
			 (define (goto-reg-proc)
			   (set-contents! pc (get-contents reg)))
			 goto-reg-proc))
		  (else
		   (error "[make-goto] bad goto instruction:" inst)))))

(define (goto-dest inst) (cadr inst))

;;; save and restore
(define (make-save inst machine stack pc)
  (let ((reg (get-register machine
						   (stack-inst-reg-name inst))))
	(define (save-proc)
	  (push stack (get-contents reg))
	  (advance-pc pc))
	save-proc))

(define (make-restore inst machine stack pc)
  (let ((reg (get-register machine
						   (stack-inst-reg-name inst))))
	(define (restore-proc)
	  (set-contents! reg (pop stack))
	  (advance-pc pc))
	restore-proc))

(define (stack-inst-reg-name inst) (cadr inst))

;;; perform
(define (make-perform inst machine labels ops pc)
  (let ((action (perform-action inst)))
	(if (operation-exp? action)
		(let ((action-proc (make-operation-exp action machine labels ops)))
		  (define (perform-proc)
			(action-proc)
			(advance-pc pc))
		  perform-proc)
		(error "[make-perform] bad instruction:" inst))))

(define (perform-action inst) (cdr inst))


;;; expressions
(define (make-primitive-exp exp machine labels)
  (cond ((constant-exp? exp)
		 (let ((const (constant-exp-value exp)))
		   (define (const-proc) const)
		   const-proc))
		((label-exp? exp)
		 (let ((insts (lookup-label labels (label-exp-label exp))))
		   (define (label-proc) insts)
		   label-proc))
		((register-exp? exp)
		 (let ((reg (get-register machine (register-exp-reg exp))))
		   (define (reg-proc) (get-contents reg))
		   reg-proc))
		(else
		 (error "[make-primitive-exp] unknown expression type:" exp))))

(define (make-operation-exp exp machine labels ops)
  (let ((op (lookup-prim (operation-exp-op exp) ops))
		(procs (map (lambda (exp)
;;					  (if (label-exp? exp)
;;						  (error "[make-operation-exp] cannot use label:" + exp)
;;						  (make-primitive-exp exp machine labels)))
						  (make-primitive-exp exp machine labels))
					(operation-exp-operands exp))))
	(define (op-proc)
	  (apply op (map (lambda (proc) (proc)) procs)))
	op-proc))

(define (lookup-prim key ops)
  (let ((val (assoc key ops)))
	(if val
		(cadr val)
		(error "[make-operation-exp] unknown operation: " key))))

(define (constant-exp? exp) (my-tagged-list? exp 'const))
(define (constant-exp-value exp) (cadr exp))

(define (label-exp? exp) (my-tagged-list? exp 'label))
(define (label-exp-label exp) (cadr exp))

(define (register-exp? exp) (my-tagged-list? exp 'reg))
(define (register-exp-reg exp) (cadr exp))

(define (operation-exp? exp) (and (pair? exp) (my-tagged-list? (car exp) 'op)))
(define (operation-exp-op exp) (cadr (car exp)))
(define (operation-exp-operands exp) (cdr exp))

;;; from chapter 4.1
(define (my-tagged-list? exp tag)
  (if (pair? exp)
	  (eq? (car exp) tag)
	  false))

'(REGISTER SIMULATOR LOADED)

(provide (all-defined-out))

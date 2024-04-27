	.org	1800h
	
	ld	a, 5
	ld	b, 4
	add	a, b
	ld	(1830h), a
	halt
	
	.end
	
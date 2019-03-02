def fun():
	L=[1]
	while True:
		yield L
		L = [sum(i) for i in zip([0]+L,L+[0])]

f = fun()
for i in range(25):
	print(next(f))

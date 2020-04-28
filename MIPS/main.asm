#Author: Patryk Karbownik
#Project: Obroty obrazu BMP przy uzyciu przeksztalcenia afinicznego

	.data
.align 4
	
fname:	.asciiz "image.bmp" #nazwa zrodlowej bitmapy
rfname:	.asciiz	"result.bmp"#nazwa bitmapy z wynikiem
text0:	.asciiz "Podaj wartosc sinusa: \n"
text1:	.asciiz "Podaj wartosc cosinusa: \n"
res:	.space 3
fileCopy:.space 3200000 #pamiec na kopie bitmapy zrodlowej
pixArray:.space 3200000	#pamiec do zapisu pixel array po obrocie

	
	.text
	.globl main
	
####################################################
	# Rejestry ze stalymi:
	# $s3, height
	# $s4, width
	# $s5, newPadding
	# $s6, oldPadding 
	# $t5, dim
	# $t6, sin
	# $t7, cos
	# $t8, x #wspolrzedna x srodka bitmapy zrodlowej
	# $t9, y #wspolrzedna y srodka bitmapy zrodlowej

main:
#################################
#Wyswietlanie zapytania o wartosc sinusa

	li $v0, 4     
	la $a0, text0 
	syscall	      
	
#Wczytywanie wartosci sinusa

	li $v0, 5	
	syscall
	move $t6, $v0 #zapis wartosci sinusa do rejestru $t6
	
#Wyswieltanie zapytania o wartosc cosinusa
	
	li $v0, 4	
	la $a0, text1
	syscall
	
#Wczytywanie wartosci cosinusa
	
	li $v0, 5
	syscall
	move $t7, $v0 #zapis wartosci cosinuda do rejestru $t7
	
readBMP:	
#Open file
	
	li $v0, 13
	la $a0, fname
	li $a1, 0
	li $a2, 0
	syscall
	move $t0, $v0
	
#Read file
	
	li $v0, 14
	move $a0, $t0
	la $a1, fileCopy
	li $a2, 3200000
	syscall
	
#Close file
	
	li $v0, 16
	move $a0, $t0
	syscall

#Odczyt i zapis wartosci width, height z bitmapy
	
	lw $t0, fileCopy + 18
	lw $t1, fileCopy + 22
	
	move $s3, $t1 #zapis height do rejestru $s3
	move $s4, $t0 #zapis width do rejestru $s4
	
newBitmapDimension:

#porownywanie width z height
#width nowej bitmapy = height nowej bitmapy = dim = 2 * (większa wartosc z width, heigth source bitmap)

	bgt $t0, $t1, newDimensionElse
	
	sll $t1, $t1, 1
	move $t5, $t1 #zapis dim do rejestru $t5
	srl $t1, $t1,1
	
	j setBitmapCentre
	
newDimensionElse:

	sll $t0, $t0, 1
	move $t5, $t1 #zapis dim do $t5
	srl $t0, $t0, 1
	
#Obliczenie i zapis wspolrzednych srodka bitmapy
setBitmapCentre:
	
	sra $t0, $t0, 1 # width / 2 
	sra $t1, $t1, 1	# height / 2
	move $t8, $t0 # zapis x srodka bitmapy do rejestru $t8
	move $t9, $t1 # zapiy y srodka bitmapy do rejestru $t9
	
oldPaddingCalculation:
	
	andi $t1, $s4, 0x03 # width % 4		
	move $s6, $t1 # zapis paddingu bitmapy zrodlowej do rejestru $s6

newPaddingCalculation:
	
	andi $t1, $t5, 0x03 # dim % 4	
	move $s5, $t1 # zapis paddingu bitmapy wynikowej do rejestru $s5

	li $s0, 0 #zmienna do iterowania względem height
	li $s1, 0 #zmienna do iterowania względem width
	la $s7, fileCopy + 54 #poczatek pixelArray w bitmapie zrodlowej
	
translateToXY: #przeliczanie na kartezjanskie wspolrzedne

	sub $t0, $s1, $t8 #wyliczanie x = current width - x srodka
	sub $t1, $s0, $t9 #wyliczanie y = current height - y srodka
	
getNewPosition:
	# Wejscie
	# $t0 -> x 
	# $t1 -> y
	
	#obliczanie nowej wspolrzednej x
	mul $t2, $t0, $t7 # x * cos 
	mul $t3, $t1, $t6 # y * sin
	sub $t2, $t2, $t3 # (x*cos) - (y*sin)
	
	#obliczenie nowej wspolrzednej y
	mul $t3, $t0, $t6 # x * sin
	mul $t4, $t1, $t7 # y * cos
	add $t3, $t3, $t4 # (x*sin) + (y*cos)
	
	sra $t2, $t2, 20 #usuwanie zawartosci po przecinku
	sra $t3, $t3, 20 #usuwanie zawartosci po przecinku
	
	# Wyjscie:
	# $t2 -> new X
	# $t3 -> new Y
translateToWidthHeight:
	# Wejscie
	# $t2 -> new X
	# $t3 -> new Y
	
	sra $t4, $t5, 1   # <- wyliczenie srodka bitmapy wynikowej
	add $t0, $t2, $t4 # new X + X srodka <- tutaj ustalamy lokalizacje wg srodka bitmapy wynikowej
	add $t1, $t3, $t4 # new Y + Y srodka
	
	# Wyjscie
	# $t0 -> new width
	# $t1 -> new height
calculateDestinationAddress:
	# Wejscie
	# $t0 -> new width
	# $t1 -> new height
	# 
	# Wzor
	# adres = new height * (newPadding + 3 * dim) + 3 * new width 
	
	mul $t2, $t5, 3 #3 * dim
	add $t2, $t2, $s5 #newPadding + (3 * dim)
	mul $t2, $t2, $t1 #height * (newPadding + 3 * dim)
	mul $t0, $t0, 3 # 3 * new width
	add $t2, $t2, $t0 # [height * (newPadding + 3 * dim)] + 3 * new width 
	
	# Wyjscie
	# $t2 -> destinationAdress
calculateSourceAddress:
	# Wejscie
	# $s0 -> currentHeight
	# $s1 -> currentWidth
	# $s6 -> oldPadding
	#
	# Wzor
	# adres = currentHeight * (oldPadding + 3 * width) + 3 * currentWidth + adres poczatku bitmapy
	
	mul $t3, $s4, 3 # 3 * width
	add $t3, $t3, $s6 # oldPadding + (3 * width)
	mul $t3, $t3, $s0 # currentHeight * ( oldPadding + 3 * width)
	mul $t0, $s1, 3   # 3 *currentWidht
	add $t3, $t3, $t0 # [currentHeight * (oldPadding + 3 * width)] + (3 * currentWidth) 
	add $t3, $t3, $s7 # [currentHeight * (oldPadding + 3 * width) + 3 * currentWidth] + adres poczatku bitmapy
		
	# Wyjscie
	# $t3 -> sourceAdress
getPixel:
	# Wejscie
	# $t3 -> sourceAdress
	
	lb $t0, 0($t3)
	lb $t1, 1($t3)
	lb $t4, 2($t3)
		
	# Wyjscie
	# $t0, $t1, $t4 -> kolejne barwy
savePixel:
	# Wejscie
	# $t0, $t1, $t4 -> kolejne barwy
	
	sb $t0, pixArray + 0($t2)
	sb $t1, pixArray + 1($t2)
	sb $t4, pixArray + 2($t2)

innerLoopControlPoint:

	addi $s1, $s1, 1 #inkrementacja zmiennej do iterowania wzgledem width
	
	blt $s1, $s4, translateToXY #if s1 < width go to translateToXY
	
	addi $s0, $s0, 1 #inkrementacja zmiennej do iterowania wzgledem height
	
	li $s1, 0
	
	blt $s0, $s3, translateToXY #if s0 < height go to translateToXY
	
modifyHeader:
	
	sw $t5, fileCopy + 18 #podmiana width na dim
	sw $t5, fileCopy + 22 #podmiana height na dim
	
	mul $t0, $t5, 3 # 3 * dim
	add $t0, $s5, $t0 # 3 * dim + padding -> rowSize
	mul $t0, $t0, $t5 # rowSize * dim = biSizeImage
	
	move $t1, $t0 #kopia zapasowa biSizeImage
	
	lw $t0, fileCopy + 34
	addi $t0, $t0, 54 #Zwiekszamy o 54 zeby dostac rozmiar pliku
	
	lw $t0, fileCopy + 2
	
	la $t2, fileCopy + 54 #ladujemy adres poczatku pixel array
	li $t3, 0 #zmienna do iterowania
	
copyResultBMP:

	lb $t4, pixArray + 0($t3) #pobieranie bajtu z result bmp
	sb $t4, ($t2) #zapis tego bajtu
	
	addi $t2, $t2, 1 #inkrementujemy wskaznik na adres w fileCopy
	addi $t3, $t3, 1 #inkrementujemy licznik
	ble $t3, $t1, copyResultBMP #porownanie
	
saveFile:
	addi $t1, $t1, 54	# biSizeImage + 54 -> rozmiar pliku
	li $v0, 13		#open file
        la $a0, rfname		#nazwa bitmapy wynikowej
        li $a1, 1		#1 -> write
        li $a2, 0		
        syscall
	move $s1, $v0      	# zapisujemy file descriptor
	
	#save file
	li $v0, 15		#zapisywane
	move $a0, $s1		#file descriptor
	la $a1, fileCopy	#buffer
	la $a2, ($t1)		
	syscall
		
	#Close file
	li $v0, 16
	move $a0, $s1
	syscall
	
#Koniec programu	
exit:	li $v0, 10
	syscall
	


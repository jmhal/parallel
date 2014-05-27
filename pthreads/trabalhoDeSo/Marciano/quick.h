#ifndef QUICK_H
#define QUICK_H

#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include "lista.h"
#include "funcoes.h"

#define bool int
#define true 1
#define false 0

void insertion(Lista *L){
	for(Nodo *aux=L->primeiro->prox ; aux != NULL ; aux=aux->prox){
		int valor=aux->valor;
		Nodo *j=aux->ant;
		Nodo *anterior;
		while(j != NULL  && valor < j->valor){
			j->prox->valor=j->valor;
			anterior=j;
			j=j->ant;
		}
		if(j == NULL)
			anterior->valor=valor;
		else
			j->prox->valor=valor;
	}
}

void quick(Nodo *p,Nodo *q, int tam){
	if(tam <=2){
		return;
	}else{
		int pivo=p->valor;
		Nodo * inicio=p->prox;
		Nodo * fim=q;
		int in=1;
		int fi=tam-1;
		
		do{
			while(in < tam && inicio->valor <= pivo){
				in++;
				inicio=inicio->prox;
			}
			while(fim->valor > pivo){
				fi--;
				fim=fim->ant;
			}
			if(in <= fi){
				swap(&inicio->valor, &fim->valor);
				in++;
				fi--;
				inicio=inicio->prox;
				fim=fim->ant;
			}
		}while(in <= fi);
		p->valor=fim->valor;
		fim->valor=pivo;

		quick(p,fim,fi);
		quick(inicio,q,tam-in);
	}
}

/*
 * e aqui onde acontece a magia, aqui eu pego uma lista e ordeno ela
 * com dois algoritmos diferentes, agora voce pode esta se perguntando:
 * "Mais porque dois?", e o seguinte, primeiramente eu ordeno com o
 * Quick-Sort,esse algoritmo e muito bom para ordenar valores aleatorios
 * mais perssimo para ordenar valores quase ordenados; depois eu ordeno
 * usando o Insertion_Sort, antes do Quick_Sort rdenar por completo a
 * lista eu "mato" ele, ou seja, ele sair antes de ordenar a lista, porem
 * a deixa quanse ordenada, por isso que eu uso o insertion-sort para
 * acabar de ordenar, como o insertion-sort e o melhor algoritmo para
 * ordenar valores quase ordenado, ele acaba sendo mais rapido do que o
 * quick-sort seria para ordenar essa lista pois os valores estao quase
 * ordenados.
 */
void ordena(Lista *L){
	quick(L->primeiro, L->ultimo, L->n);
	insertion(L);
	return;
}

#endif

#include <pthread.h>
#include <stdio.h>
#include <unistd.h>

pthread_cond_t cond_full  = PTHREAD_COND_INITIALIZER;
pthread_cond_t cond_empty = PTHREAD_COND_INITIALIZER;

pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;

int resource = 0;
int counter = 0; 

void* supplier(void* arg)
{
    while (1) {
        pthread_mutex_lock(&lock);

        while (resource == 1) {
            pthread_cond_wait(&cond_empty, &lock);
        }

        resource = 1;
        counter++;
        printf("Provided №%d\n", counter);

        pthread_cond_signal(&cond_full);
        pthread_mutex_unlock(&lock);

        sleep(1);
    }

    return NULL;
}

void* consumer(void* arg)
{
    while (1) {
        pthread_mutex_lock(&lock);

        while (resource == 0) {
            pthread_cond_wait(&cond_full, &lock);
        }

        resource = 0;
        printf("Consumed №%d\n", counter);

        pthread_cond_signal(&cond_empty);
        pthread_mutex_unlock(&lock);

        sleep(1);
    }

    return NULL;
}

int main()
{
    pthread_t supplier_thread, consumer_thread;

    pthread_create(&supplier_thread, NULL, supplier, NULL);
    pthread_create(&consumer_thread, NULL, consumer, NULL);

    pthread_join(supplier_thread, NULL);
    pthread_join(consumer_thread, NULL);
    return 0;
}

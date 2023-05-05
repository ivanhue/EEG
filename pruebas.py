import multiprocessing as mp
import julia

def run_julia(args, result_queue):
    # Inicializar el entorno de Julia
    jl = julia.Julia()
    
    # Ejecutar el código de Julia
    result = jl.eval("1 + 2")
    
    # Enviar el resultado al proceso principal
    result_queue.put(result)

if __name__ == "__main__":
    # Crear la cola para los resultados
    result_queue = mp.Queue()
    
    # Crear el proceso de Julia
    p = mp.Process(target=run_julia, args=((1,), result_queue))
    
    # Iniciar el proceso de Julia
    p.start()
    
    # Esperar a que el proceso de Julia termine
    p.join()
    
    # Obtener el resultado de la cola
    result = result_queue.get()
    
    print(result)

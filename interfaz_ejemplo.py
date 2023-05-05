import customtkinter
import time
import tkinter as tk
from tkinter import filedialog
import tkinter as tk
import threading
import multiprocessing
import logging as log
log.basicConfig(
    level=log.INFO,
    format='%(asctime)s %(message)s',
    datefmt='%H:%M:%S'
    )


INICIAR_JULIA = True

# def iniciar_julia():
if INICIAR_JULIA:
    log.info(" ********** Iniciando Julia ********** ")
    # Import julia to python
    from julia.api import Julia
    jl = Julia(compiled_modules=False)
    from julia import Main
    jl.eval('include("pruebas.jl")')
    log.info(" ********** Julia iniciada **********")

# t = threading.Thread(target=iniciar_julia)
# t.start()


customtkinter.set_appearance_mode("Dark")
customtkinter.set_default_color_theme("dark-blue")

class ConfiguracionesFrame(customtkinter.CTkFrame):
    def __init__(self, master):
        super().__init__(master)
        self.app = master
        # Nombre del frame
        self.label_opciones = customtkinter.CTkLabel(self, text="Opciones:")
        self.label_opciones.grid(row=0, column=0, padx=20, pady=5, sticky="ew")
        # Boton para elegir archivo
        self.button = customtkinter.CTkButton(self, text="Elegir archivo data", command=self.button_callback)
        self.button.grid(row=1, column=0, padx=10, pady=20, sticky="ew")
        # Mostrar archivo seleccionado
        self.label2 = customtkinter.CTkLabel(self, text="Archivo no seleccionado", text_color="yellow")
        self.label2.grid(row=2, column=0, padx=0, pady=0, sticky="ew", columnspan=3)
        # Boton calcular resultados
        self.button2 = customtkinter.CTkButton(self, text="Calcular trayectorias", command=self.button_trayectory, state="disabled")
        self.button2.grid(row=3, column=0, padx=10, pady=20, sticky="ew", columnspan=1)


    def button_callback(self):
        self.filepath = filedialog.askopenfilename(filetypes=(("Archivos DAT", "*.dat"),))
        if self.filepath == "":
            self.filepath = "Archivo no seleccionado"
        else:
            if type(self.filepath) == str:
                self.button2.configure(state="normal")
                # Obtiene el nombre del archivo
                self.label2.configure(text=self.filepath.split("/")[-1])
        print('Selected:', self.filepath)


    def button_trayectory(self):
        self.button2.configure(state="disabled")
        self.app.progressbar.start()
        t = multiprocessing.Process(target=self.calcular_trayectorias, daemon=True)# threading.Thread(target=self.calcular_trayectorias)
        t.start()

        t.join()
        # Actualiza el estado de la interfaz gráfica mientras se realizan los cálculos
        while t.is_alive():
            self.update()
            time.sleep(0.1)
        
        self.app.progressbar.stop()
        self.button2.configure(state="normal")
    
    def calcular_trayectorias(self):
        time.sleep(5)
        if not INICIAR_JULIA:
            raise Exception("No se ha iniciado julia")
        else:
            log.info(" ********** Calculando resultados ********** ")
            
            
            # threading.Thread(target=obtener_resultados).start()
            Main.data = self.filepath
            jl.eval('resultados(data)')
            log.info(" ********** Termino de calcular ********** ")
            


class ResultsFrame(customtkinter.CTkFrame):
    def __init__(self, master):
        super().__init__(master)
        self.label = customtkinter.CTkLabel(self, text="Resultados:")
        self.label.grid(row=0, column=0, padx=20, pady=5, sticky="ew")
    


class App(customtkinter.CTk):
    def __init__(self):
        super().__init__()

        self.title("Spike sorting")
        self.geometry("800x600")
        self.grid_columnconfigure(0, weight=0)
        self.grid_columnconfigure(1, weight=1)
        self.grid_rowconfigure(0, weight=1)
        self.grid_rowconfigure(1, weight=0)

        self.progressbar = customtkinter.CTkProgressBar(master=self, mode='indeterminate')
        self.progressbar.grid(row=1, column=0, padx=20, pady=(3,10), sticky="ew", columnspan=2)
        
        self.configuraciones_frame = ConfiguracionesFrame(self)
        self.configuraciones_frame.grid(row=0, column=0, padx=(20,5), pady=(15,5), sticky="nsew")

        self.reultados_frame = ResultsFrame(self)
        self.reultados_frame.grid(row=0, column=1, padx=(5,20), pady=(15,5), sticky="nsew", columnspan=2)
        

        

def main():
    app = App()
    app.mainloop()



if __name__ == "__main__":
    main()
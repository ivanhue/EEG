import customtkinter
import time
import os
from tkinter import filedialog
from tkinter import PhotoImage
import tkinter as tk
from PIL import Image
import threading
import multiprocessing
import logging as log
log.basicConfig(
    level=log.INFO,
    format='%(asctime)s %(message)s',
    datefmt='%H:%M:%S'
    )


INICIAR_JULIA = False
INDICE_ARCHIVO = 0
folder_path = ""



files = []

# def iniciar_julia():
if INICIAR_JULIA:
    log.info(" ********** Iniciando Julia ********** ")
    # Import julia to python
    from julia.api import Julia
    jl = Julia(compiled_modules=False)
    from julia import Main
    jl.eval('include("main.jl")')
    log.info(" ********** Julia iniciada **********")

# t = threading.Thread(target=iniciar_julia)
# t.start()


customtkinter.set_appearance_mode("Dark")
customtkinter.set_default_color_theme("dark-blue")

class ConfiguracionesFrame(customtkinter.CTkFrame):
    """
    Frame con todos los botones y etiquetas de configuracion.

    Metodos:
    - Boton cargar archivos.
    - Boton calcular trayectoria.
    - Boton graficar.
    - Calcular trayectorias.

    Widgets:
    - Etiqueta opciones.
    - Boton elegir archivo.
    - Etiqueta archivo no seleccionado.
    - Boton calcular trayectorias.
    - Boton graficar.

    """
    def __init__(self, master):
        super().__init__(master)
        self.app = master
        # Nombre del frame
        self.label_opciones = customtkinter.CTkLabel(self, text="Opciones:")
        self.label_opciones.grid(row=0, column=0, padx=20, pady=5, sticky="w")
        # Boton para elegir archivo
        self.button = customtkinter.CTkButton(self, text="Elegir archivo data", command=self.button_loadfile)
        self.button.grid(row=1, column=0, padx=10, pady=20, sticky="ew")
        # Mostrar archivo seleccionado
        self.label2 = customtkinter.CTkLabel(self, text="Archivo no seleccionado", text_color="yellow")
        self.label2.grid(row=2, column=0, padx=0, pady=0, sticky="ew", columnspan=3)
        # Boton calcular resultados
        self.button2 = customtkinter.CTkButton(self, text="Calcular trayectorias", command=self.button_trayectory, state="disabled")
        self.button2.grid(row=3, column=0, padx=10, pady=20, sticky="ew", columnspan=1)
        # Boton mostrar resultados
        self.button3 = customtkinter.CTkButton(self, text="Graficar", command=self.button_plot, state="disabled")
        self.button3.grid(row=4, column=0, padx=10, pady=20, sticky="ew", columnspan=1)

    def button_loadfile(self):
        """
        Boton cargar archivo. Obtiene la dirección del archivo.
        """
        global folder_path, files
        self.filepath = filedialog.askopenfilename(filetypes=(("Archivos DAT", "*.dat"),))
        if self.filepath == "":
            self.filepath = "Archivo no seleccionado"
        else:
            if type(self.filepath) == str:
                self.button2.configure(state="normal")
                self.button3.configure(state="normal")
                # Obtiene el nombre del archivo
                self.label2.configure(text=self.filepath.split("/")[-1])
                folder_path = self.filepath.split("/")[-1]
                folder_path = folder_path +"gifs"
                for file_name in os.listdir(folder_path):
                    files.append(file_name)

        print('Selected:', self.filepath)

    
    def button_trayectory(self):
        """
        Boton para calcular las trayectorias. Interfaz para su procesamiento, hilos, procesadores.
        """
        self.button2.configure(state="disabled")
        self._calcular_trayectorias()
        # self.app.progressbar.start()
        # t = threading.Thread(target=self._calcular_trayectorias)
        # t = multiprocessing.Process(target=self._calcular_trayectorias, daemon=False)
        # t.start()

        # t.join()
        # Actualiza el estado de la interfaz gráfica mientras se realizan los cálculos
        # while t.is_alive():
        #     self.update()
        #     time.sleep(0.1)
        
        # self.app.progressbar.stop()
        self.button2.configure(state="normal")
    
    def button_plot(self):
        """
        Boton graficar. EJecuta el codigo Julia. Crea una carpeta y guarda todos los archivos '.gif' generados
        """
        if not INICIAR_JULIA:
            raise Exception("No se ha iniciado julia")
        else:
            log.info(" ********** Graficando ********** ")
            # Main.trayp = self.trayp
            # Main.traynp = self.traynp
            # Main.MVcsda = self.MVcsda
            # Main.ruta_resultados = self.ruta_resultados
            Main.resultados = self.resultados
            # jl.eval('visualize_resultados(trayp, traynp, MVcsda, ruta_resultados)')
            jl.eval('visualize_resultados(resultados)')
    
    def _calcular_trayectorias(self):
        """
        Ejecuta codigo Julia. Crea carpeta con los resultados obtenidos.
        """
        time.sleep(5)
        if not INICIAR_JULIA:
            raise Exception("No se ha iniciado julia")
        else:
            log.info(" ********** Calculando resultados ********** ")
            
            
            # threading.Thread(target=obtener_resultados).start()
            Main.path = self.filepath
            # self.trayp, self.traynp, self.MVcsda, self.ruta_resultados = jl.eval('resultados(data)')
            self.resultados = jl.eval('resultados(path)')
            log.info(" ********** Termino de calcular ********** ")
            


class ResultsFrame(customtkinter.CTkFrame):
    """
    Frame que maneja todos los resultados obtenidos de los calculos y archivos generados por Julia.
    """
    def __init__(self, master):
        super().__init__(master)
        global files
        self.label = customtkinter.CTkLabel(self, text="Resultados:")
        self.label.grid(row=0, column=0, padx=20, pady=5, sticky="w")
        if files != []:
            im = Image.open(files[INDICE_ARCHIVO])
            im = customtkinter.CTkImage(dark_image=im, size=(600,400))
            # im = PhotoImage(file="exp136_Igancio_32CH_Resultadosgifs/CSDA_13.gif", format="gif")
            self.image = customtkinter.CTkLabel(self, image=im, text="")
            self.image.grid(row=1, column=0, padx=20, pady=5, sticky="ew")

            self.buttonLeft = customtkinter.CTkButton(self,text="Anterior")
            self.buttonLeft.grid(row=2, column=0, padx=20, pady=10, sticky="w")
            self.buttonRight = customtkinter.CTkButton(self,text="Siguiente")
            self.buttonRight.grid(row=2, column=0, padx=20, pady=10, sticky="e")
    


class App(customtkinter.CTk):
    def __init__(self):
        super().__init__()

        self.title("Spike sorting")
        self.geometry("850x600")
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
## Lista de chequeo PCB

- [ ] ¿Pasa el esquemático las reglas DRC?
- [ ] ¿Pasa el trazado de la PCB las reglas DRC?
- [ ] ¿Hay paridad entre esquemático y PCB?
- [ ] ¿Necesita conexión de prueba para masa? Y si es así, ¿la tiene?
- [ ] ¿Se tiene las medidas del lugar donde va a ser utilizada la PCB?
- [ ]  ¿Se ha verificado la disponibilidad de dispositivos y elementos que vaya a necesitar la PCB para su correcto funcionamiento?
- [ ]  ¿Se ha revisado la hoja de datos de cada dispositivo o elemento?
- [ ]  ¿Se ha elegido la _**footprint/Package**_, adecuada para el proyecto?
- [ ]  ¿La huella tiene patio cerrado?
- [ ]  ¿Se ha revisado la compatibilidad eléctrica de todos los dispositivos?
- [ ]  ¿Se ha verificado las condiciones y/o reglas de diseño del fabricante? 
- [ ]  ¿Se ha hecho uso de los máximos y minimos en dimensiones para la selección de huella de los dispositivos discretos, y en el caso de tener que diseñar una huella?
- [ ]  ¿Genera alguna huella un error por ausencia de patio? Si la huella es sólo serigrafía, marcar en **_propiedades de huella_ -> _exento del requisito del patio_**. De esta manera no se generará error al pasar **DRC**.
- [ ]  ¿Hay información importante de los diferentes dispositivos en la PCB?
- [ ]  ¿Se ha versionado la PCB en caso de sufrir cambios o mejoras?
- [ ]  ¿Coincide  la lista BOM con el esquemático?
- [ ]  ¿Se ha verificado visualmente VCC y VSS en cada integrado y como entradas de alimentación?
- [ ]  ¿Concuerda con la hoja de datos VCC y VSS en los dispositivos?

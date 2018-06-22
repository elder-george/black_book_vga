
%macro FILE_DELETE 1
%define filename %1
    mov ah, 41h
    mov dx, filename
    int 21h
%endmacro

%macro FILE_CREATE 2
%define filename %1
%define attr     %2
    mov dx, filename
    mov cx, attr
    mov ah, 3ch
    int 21h
%endmacro

%macro FILE_OPEN 2
%define filename %1
%define attr     %2
    mov dx, filename
    mov al, attr
    mov ah, 3dh
    int 21h
%endmacro


%macro FILE_WRITE 4
%define handle          %1
%define src_seg         %2
%define src_off         %3
%define size_in_bytes   %4
    mov bx, handle
    mov dx, src_off
    mov cx, size_in_bytes
    mov ah, 40h
    int 21h
%endmacro

%macro FILE_READ  4
%define handle          %1
%define src_seg         %2
%define src_off         %3
%define size_in_bytes   %4
    mov bx, handle
    mov dx, src_off
    mov cx, size_in_bytes
    mov ah, 3fh
    int 21h
%endmacro

%macro FILE_CLOSE 1
    mov ah, 3eh
    mov bx, %1
    int 21h
%endmacro

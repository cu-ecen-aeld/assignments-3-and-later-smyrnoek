# Compiler selection
CC := $(CROSS_COMPILE)gcc

# Target binary name
TARGET := writer

# Source file
SRC := writer.c

# Object file
OBJ := writer.o

# Default target: Build the writer application
all: $(TARGET)

# Compile source file into object file
$(OBJ): $(SRC)
	$(CC) -c $< -o $@

# Link object file into final executable
$(TARGET): $(OBJ)
	$(CC) $(OBJ) -o $(TARGET)

# Clean target: Removes the binary and object files
clean:
	rm -f $(TARGET) $(OBJ)

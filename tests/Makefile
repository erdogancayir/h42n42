SRC_DIR := ../src
BUILD   := _build
TEST    := $(BUILD)/test_rules

all: $(TEST)
	./$(TEST)

$(TEST): $(SRC_DIR)/rules.ml test_rules.ml | $(BUILD)
	cp $^ $(BUILD)/
	cd $(BUILD) && ocamlfind ocamlopt rules.ml test_rules.ml -o test_rules

$(BUILD):
	mkdir -p $@

clean:
	rm -rf $(BUILD)

.PHONY: all clean

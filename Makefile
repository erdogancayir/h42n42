NAME        := h42n42
PORT        ?= 8080

SRC_DIR     := src
SERVER_DIR  := _server
CLIENT_DIR  := _client
STATIC_DIR  := static
LOCAL_DIR   := local
TEST_DIR    := tests

# eliomc and js_of_eliom keep the source path inside their output directory
SERVER_OUT  := $(SERVER_DIR)/$(SRC_DIR)
CLIENT_OUT  := $(CLIENT_DIR)/$(SRC_DIR)

# Modules in dependency order
ELIOM_MODULES  := creet game h42n42
CLIENT_MODULES := rules $(ELIOM_MODULES)

PACKAGES    := -package lwt_ppx
SERVER_PKGS := $(PACKAGES) -I $(SERVER_OUT)
CLIENT_PKGS := $(PACKAGES) -package js_of_ocaml-ppx -I $(CLIENT_OUT)

# JavaScript implementation of the bigstringaf primitives used by eliom.client
JS_RUNTIME  := $(shell ocamlfind query bigstringaf 2>/dev/null)/runtime.js

SERVER_OBJS := $(ELIOM_MODULES:%=$(SERVER_OUT)/%.cmo)
CLIENT_OBJS := $(CLIENT_MODULES:%=$(CLIENT_OUT)/%.cmo)

SERVER_LIB  := $(SERVER_DIR)/$(NAME).cma
CLIENT_JS   := $(STATIC_DIR)/$(NAME).js
CONF        := $(NAME).conf
LOCAL_DIRS  := $(LOCAL_DIR)/log $(LOCAL_DIR)/data $(LOCAL_DIR)/run

all: $(SERVER_LIB) $(CLIENT_JS) $(CONF) | $(LOCAL_DIRS)

# Server side
$(SERVER_OUT)/%.type_mli: $(SRC_DIR)/%.eliom
	eliomc -ppx -infer $(SERVER_PKGS) $<

$(SERVER_OUT)/%.cmo: $(SRC_DIR)/%.eliom $(SERVER_OUT)/%.type_mli
	eliomc -ppx -c $(SERVER_PKGS) $<

$(SERVER_LIB): $(SERVER_OBJS)
	eliomc -a -o $@ $^

# Client side
$(CLIENT_OUT)/rules.cmo: $(SRC_DIR)/rules.ml
	js_of_eliom -ppx -c $<

$(CLIENT_OUT)/%.cmo: $(SRC_DIR)/%.eliom $(SERVER_OUT)/%.type_mli
	js_of_eliom -ppx -c $(CLIENT_PKGS) $<

$(CLIENT_JS): $(CLIENT_OBJS)
	js_of_eliom -o $@ $(CLIENT_PKGS) -jsopt $(JS_RUNTIME) $^

# Keep the inferred types, otherwise make deletes them and rebuilds every time
.PRECIOUS: $(SERVER_OUT)/%.type_mli

# Dependencies between modules
$(SERVER_OUT)/game.type_mli: $(SERVER_OUT)/creet.cmo
$(SERVER_OUT)/h42n42.type_mli: $(SERVER_OUT)/game.cmo
$(CLIENT_OUT)/creet.cmo: $(CLIENT_OUT)/rules.cmo
$(CLIENT_OUT)/game.cmo: $(CLIENT_OUT)/creet.cmo
$(CLIENT_OUT)/h42n42.cmo: $(CLIENT_OUT)/game.cmo

# Ocsigen server configuration
$(CONF): $(NAME).conf.in Makefile
	sed -e "s|%%PORT%%|$(PORT)|g" \
	    -e "s|%%ROOT%%|$(CURDIR)|g" \
	    -e "s|%%NAME%%|$(NAME)|g" $< > $@

$(LOCAL_DIRS):
	mkdir -p $@

run: all
	ocsigenserver -c $(CONF)

test:
	$(MAKE) -C $(TEST_DIR)

clean:
	rm -rf $(SERVER_DIR) $(CLIENT_DIR)
	$(MAKE) -C $(TEST_DIR) clean

fclean: clean
	rm -rf $(CLIENT_JS) $(CONF) $(LOCAL_DIRS)

re: fclean all

.PHONY: all run test clean fclean re

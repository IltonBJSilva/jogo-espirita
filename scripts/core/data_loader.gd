class_name DataLoader
extends RefCounted
## Leitura de arquivos de dados (JSON) usados por dialogos, missoes e itens.
##
## Observacao para exportacao: inclua "*.json" em
## Projeto > Exportar > Recursos > Filtros para exportar arquivos que nao sao recursos.


## Carrega um arquivo JSON e devolve um Dictionary (vazio em caso de erro).
static func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("DataLoader: arquivo nao encontrado: %s" % path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("DataLoader: JSON invalido em %s (linha %d): %s"
				% [path, json.get_error_line(), json.get_error_message()])
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("DataLoader: %s deve conter um objeto JSON na raiz." % path)
		return {}
	return json.data


## Carrega todos os .json de uma pasta. Devolve {nome_do_arquivo_sem_extensao: dados}.
static func load_json_dir(dir_path: String) -> Dictionary:
	var result := {}
	for file in DirAccess.get_files_at(dir_path):
		if file.get_extension() == "json":
			result[file.get_basename()] = load_json(dir_path.path_join(file))
	return result

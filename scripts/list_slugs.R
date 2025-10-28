yaml <- tryCatch(yaml::read_yaml("config/datasets.yaml"), error=function(e) NULL)
if (is.null(yaml)) quit(save="no", status=1)
cat(paste(vapply(yaml$datasets, `[[`, "", "slug"), collapse="\n"))

id <- . <- variable <- count <- percent <- target_count <- target_rate <- target_percent <- non_target_count <- non_target_percent <- odds <- woe <- iv <- NULL
. <- variable <- var <- value <- total <- value_fmt <- value_fmt2 <- NULL
count_format <- target_rate_format <- NULL
#' Bivariate Table
#' @description This function calculate a bivariate table.
#' @param variable A variable 
#' @param target A numeric binary vector {0,1}
#' @return A dplyr::data_frame object with the counts, percents and odds
#' @references http://documentation.statsoft.com/portals/0/formula%20guide/Weight%20of%20Evidence%20Formula%20Guide.pdf
#' @examples
#' data(credit)
#' 
#' variable <- credit$marital_status
#' target <- 1 - credit$bad
#'
#' bt(variable, target)
#' 
#' variable <- cut(credit$payment_day, breaks = c(-Inf, 10, 20, Inf))
#' 
#' bt(variable, target)
#'  
#' @export
bt <- function(variable, target){
  
  assertthat::assert_that(setequal(target, c(0, 1)),
                          length(target) == length(variable))
  
  tot_target <- sum(target)
  tot_non_target <- length(target) - tot_target
  
  df <- dplyr::data_frame(class = as.character(addNA(variable)), target) %>% 
    dplyr::group_by(class) %>% 
    dplyr::summarise(count = length(target),
                     percent = count/nrow(.),
                     target_count = sum(target),
                     target_rate = target_count/count,
                     target_percent = target_count/tot_target,
                     non_target_count = (count - target_count),
                     non_target_percent = (count - target_count)/tot_non_target,
                     odds = target_count/(count - target_count),
                     woe = log(target_percent/non_target_percent),
                     iv = (target_percent - non_target_percent) * woe) %>% 
    dplyr::ungroup()

  if (is.factor(variable)) {
    lvls <- levels(variable)
    df <- df %>% dplyr::mutate(class = factor(class, levels = lvls))
    df <- df[order(df$class),]
  }
  
  df
}

#' Plot Bivariate Analysis
#' @description This function calculate a bivariate table.
#' @param variable A numeric vector containing scores or probabilities
#' @param target A numeric binary vector (0, 1)
#' @param labels A par
#' @param order.by A par
#' @examples
#' 
#'\dontrun{
#' data("credit")
#' 
#' variable <- credit$sex
#' target <- credit$bad
#' 
#' gg_ba(variable, target)
#' 
#' gg_ba(variable, target, order.by = "target")
#' }
#' @export
gg_ba <- function(variable, target, labels = TRUE, order.by = NULL){
   
  df <- bt(variable, target)
  
  df2 <- df %>%
    dplyr::select(class, count, target_count, non_target_count, target_rate, odds, woe) %>% 
    tidyr::gather(var, value, -class)
  
  df3 <- df %>%
    dplyr::summarise(count = sum(count),
                     target_count = sum(target_count),
                     non_target_count = sum(non_target_count)) %>% 
    tidyr::gather(var, total)
  
  df2 <- dplyr::left_join(df2 %>% dplyr::mutate(var = as.character(var)),
                          df3 %>% dplyr::mutate(var = as.character(var)),
                          by = "var")
  
  df2 <- df2 %>%
    dplyr::mutate(value_fmt = "",
                  value_fmt = ifelse(var %in% c("count", "target_count", "non_target_count"),
                                     prettyNum(value, big.mark = ","),
                                     value_fmt),
                  value_fmt = ifelse(var %in% c("odds", "woe", "target_rate"),
                                     round(value, 2), value_fmt),
                  value_fmt2 = "",
                  value_fmt2 = ifelse(var %in% c("count", "target_count", "non_target_count"),
                                      scales::percent(value/total),
                                      value_fmt2))
                  
  df2 <- df2 %>% 
    dplyr::mutate(var = factor(var, c("count", "target_count", "non_target_count",
                                      "target_rate", "odds", "woe")))
  
  p <- ggplot(df2, aes_string("class", "value", group = 1)) +
    geom_bar(data = subset(df2, var == "count"), stat = "identity", width = 0.5) +
    geom_bar(data = subset(df2, var == "target_count"), stat = "identity", width = 0.5) +
    geom_bar(data = subset(df2, var == "non_target_count"), stat = "identity", width = 0.5) +
    geom_line(data = subset(df2, var == "target_rate")) +
    geom_point(data = subset(df2, var == "target_rate")) +
    geom_line(data = subset(df2, var == "odds")) +
    geom_point(data = subset(df2, var == "odds")) +
    geom_line(data = subset(df2, var == "woe")) +
    geom_point(data = subset(df2, var == "woe")) +
    facet_wrap(~var, scales = "free_y") +
    xlab(NULL) +
    ylab(NULL) + 
    theme(legend.position = "bottom")
  
  if (labels) {
    p <- p +
      geom_text(aes(label = value_fmt), vjust = -0.5) +
      geom_text(aes(label = value_fmt2), vjust = 1.5)
  }
  
  p
  
}

#' Plot Bivariate Analysis (2) 
#' 
#' @description A minimal version for \emph{gg_ba}
#' 
#' @param variable A numeric vector containing scores or probabilities
#' @param target A numeric binary vector (0, 1)
#' @param labels A par
#' @param order.by A par
#' 
#' @return A ggplot2 object
#' 
#' @examples
#' data("credit")
#' 
#' variable <- as.character(credit$marital_status)
#' target <- credit$bad
#' 
#' gg_ba2(variable, target)
#' gg_ba2(variable, target, labels = FALSE)
#' gg_ba2(variable, target, order.by = "odds")
#' 
#' @import ggplot2
#' 
#' @export
gg_ba2 <- function(variable, target, labels = TRUE, order.by = NULL){
  
  stopifnot(
    setequal(target, c(0, 1)),
    length(target) == length(variable)
  )
  
  
  daux <- bt(variable, target) %>% 
    dplyr::mutate(id = seq(nrow(.)), 
          count_format = prettyNum(count, big.mark = ","),
           target_rate_format = scales::percent(target_rate))

  p <- ggplot(daux) +
    geom_bar(aes(class, percent), stat = "identity", width = 0.5) +
    geom_line(aes(id, target_rate)) +
    geom_point(aes(id, target_rate)) +
    scale_y_continuous(labels = scales::percent_format()) +
    xlab(NULL) +
    ylab(NULL)
  
  if (labels) {
    p <- p +
      geom_text(aes(class, percent, label = count_format), vjust = -0.5) +
      geom_text(aes(class, target_rate, label = target_rate_format), vjust = -0.5)
  }

  p
  
}



#' Plot bivariates gg_ba
#' 
#' @examples 
#' 
#' data("credit")
#' 
#' library("ggplot2")
#' library("ggthemes")
#' theme_set(theme_fivethirtyeight(base_size = 11) +
#' theme(rect = element_rect(fill = "white"),
#' axis.title = element_text(colour = "grey30"),
#' axis.title.y = element_text(angle = 90),
#' strip.background = element_rect(fill = "#434348"),
#' strip.text = element_text(color = "#F0F0F0"),
#' plot.title = element_text(face = "plain", size = structure(1.2, class = "rel")),
#' panel.margin.x =  grid::unit(1, "cm"),
#' panel.margin.y =  grid::unit(1, "cm")))
#' update_geom_defaults("line", list(colour = "#434348", size = 1.05))
#' update_geom_defaults("point", list(colour = "#434348", size = 3))
#' update_geom_defaults("bar", list(fill = "#7cb5ec"))
#' update_geom_defaults("text", list(size = 4, colour = "gray30"))
#' 
#' plots <- ggs_biv(df = credit, target_name = "bad")
#' 
#  pdf("~/all.pdf", height = 9, width = 16)
#' bquiet = lapply(plots, print)
#' dev.off()
#'
#' @export
ggs_biv <- function(df, target_name, numeric.treatment = c("width", "autobin"),
                    nbins = 5, verbose = TRUE) {
  
  stopifnot(!is.null(target_name),
            target_name %in% names(df),
            setequal(df[[target_name]], c(0, 1)))
  
  target <- df[[target_name]]
  
  df <- df %>% dplyr::select_(paste0("-", target_name))
  
  res <- purrr::map(names(df),function(pred_var_name){
    # pred_var_name <- sample(names(df), size = 1)
    # pred_var_name <- "flag_other_card"
    
    if (verbose) message("gg bivariate: ", pred_var_name)
    
    pred_var <- df[[pred_var_name]]
    
    # Prepare data
    daux <- data.frame(target = target, pred_var = pred_var)
    daux_naomit <- na.omit(daux)
    
    if (length(unique(pred_var)) == 1)
      return(ggplot2::ggplot(daux_naomit) + ggplot2::ggtitle(pred_var_name))
    
    if (length(unique(daux_naomit$target)) == 1)
      return(ggplot2::ggplot(daux_naomit) + ggplot2::ggtitle(pred_var_name))
    
    if(is.numeric(pred_var)) {
      
      if(numeric.treatment == "width") {
        pred_var_bin <- ggplot2::cut_interval(pred_var, nbins)
      } else {
        pred_var_bin <- superv_bin(pred_var, target)$variable_new
      }
      
    } else {
      
      if(length(unique(pred_var)) < nbins) {
        pred_var_bin <- pred_var
      } else {
        pred_var_bin <- superv_bin(pred_var, target)$variable_new
      }
      
    }
    
    p <- gg_ba(pred_var_bin, target) + ggplot2::ggtitle(pred_var_name)
    
    p
    
  })
  
  res
}



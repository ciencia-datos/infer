append_infer_class <- function(x) {
  x_cl <- class(x)
  if (x_cl[1] != "infer") {
    class(x) <- c("infer", x_cl)
  }

  x
}

format_params <- function(x) {
  par_levels <- get_par_levels(x)
  fct_levels <- as.character(unique(dplyr::pull(x, !!attr(x, "response"))))
  attr(x, "params")[match(fct_levels, par_levels)]
}

get_par_levels <- function(x) {
  par_names <- names(attr(x, "params"))
  gsub("^.\\.", "", par_names)
}

copy_attrs <- function(to, from,
                       attrs = c(
                         "response", "success", "explanatory", "response_type",
                         "explanatory_type", "distr_param", "distr_param2",
                         "null", "params", "theory_type", "generate", "type"
                       )) {
  for (at in attrs) {
    attr(to, at) <- attr(from, at)
  }

  to
}

is_nuat <- function(x, at) {
  is.null(attr(x, at))
}

# Wrapper for deduplication by name after doing `c(...)`
c_dedupl <- function(...) {
  l <- c(...)
  
  l_names <- names(l)
  
  if (is.null(l_names)) {
    l
  } else {
    l[!duplicated(l_names) | (l_names == "")]
  }
}

explanatory_variable <- function(x) {
  x[[as.character(attr(x, "explanatory"))]]
}

# Other places in the code use
# dplyr::pull(x, !!attr(x, "response"))
# which seems to do the same thing
response_variable <- function(x) {
  x[[as.character(attr(x, "response"))]]
}

reorder_explanatory <- function(x, order) {
  x[[as.character(attr(x, "explanatory"))]] <- factor(
    explanatory_variable(x),
    levels = c(order[1], order[2])
  )
  x
}

has_explanatory <- function(x) {
  !is_nuat(x, "explanatory")
}

has_response <- function(x) {
  !is_nuat(x, "response")
}

is_color_string <- function(x) {
  rlang::is_string(x) &&
    tryCatch(is.matrix(grDevices::col2rgb(x)), error = function(e) {FALSE})
}

stop_glue <- function(..., .sep = "", .envir = parent.frame(),
                      call. = FALSE, .domain = NULL) {
  stop(
    glue_null(..., .sep = .sep, .envir = .envir),
    call. = call., domain = .domain
  )
}

warning_glue <- function(..., .sep = "", .envir = parent.frame(),
                         call. = FALSE, .domain = NULL) {
  warning(
    glue_null(..., .sep = .sep, .envir = .envir),
    call. = call., domain = .domain
  )
}

message_glue <- function(..., .sep = "", .envir = parent.frame(),
                         .domain = NULL, .appendLF = TRUE) {
  message(
    glue_null(..., .sep = .sep, .envir = .envir),
    domain = .domain, appendLF = .appendLF
  )
}

glue_null <- function(..., .sep = "", .envir = parent.frame()) {
  glue::glue(
    ..., .sep = .sep, .envir = .envir, .transformer = null_transformer
  )
}

# This allows to print 'NULL' in `glue()` for code which evaluates in `NULL`
null_transformer <- function(text, envir) {
  out <- eval(parse(text = text, keep.source = FALSE), envir)
  if (is.null(out)) {
    return("NULL")
  }

  out
}

check_order <- function(x, explanatory_variable, order, in_calculate = TRUE) {
  unique_ex <- sort(unique(explanatory_variable))
  if (length(unique_ex) != 2) {
    stop_glue(
      "Statistic is based on a difference or ratio; the explanatory variable", 
      "should have two levels."
    )
  }
  if (is.null(order) & in_calculate) {
    # Default to subtracting/dividing the first (alphabetically) level by the 
    # second, unless the explanatory variable is a factor (in which case order 
    # is preserved); raise a warning if this was done implicitly.
    order <- as.character(unique_ex)
    warning_glue(
      "The statistic is based on a difference or ratio; by default, for ",
      "difference-based statistics, the explanatory variable is subtracted ",
      "in the order \"{unique_ex[1]}\" - \"{unique_ex[2]}\", or divided in ", 
      "the order \"{unique_ex[1]}\" / \"{unique_ex[2]}\" for ratio-based ",
      "statistics. To specify this order yourself, supply `order = ",
      "c(\"{unique_ex[1]}\", \"{unique_ex[2]}\")` to the calculate() function."
    )
  } else if (is.null(order)) {
    order <- as.character(unique_ex)
    warning_glue(
      "The statistic is based on a difference or ratio; by default, for ",
      "difference-based statistics, the explanatory variable is subtracted ",
      "in the order \"{unique_ex[1]}\" - \"{unique_ex[2]}\", or divided in ", 
      "the order \"{unique_ex[1]}\" / \"{unique_ex[2]}\" for ratio-based ",
      "statistics. To specify this order yourself, supply `order = ",
      "c(\"{unique_ex[1]}\", \"{unique_ex[2]}\")`."
    )    
  } else {
    if (xor(is.na(order[1]), is.na(order[2]))) {
      stop_glue(
        "Only one level specified in `order`. Both levels need to be specified."
      )
    }
    if (length(order) > 2) {
      stop_glue("`order` is expecting only two entries.")
    }
    if (order[1] %in% unique_ex == FALSE) {
      stop_glue("{order[1]} is not a level of the explanatory variable.")
    }
    if (order[2] %in% unique_ex == FALSE) {
      stop_glue("{order[2]} is not a level of the explanatory variable.")
    }
  }
  # return the order as given (unless the argument was invalid or NULL)
  order
}

check_args_and_attr <- function(x, explanatory_variable, response_variable,
                                stat) {
  # Could also do `stat <- match.arg(stat)`
  # but that's not as helpful to beginners with the cryptic error msg
  if (
    !stat %in% c(
      "mean", "median", "sum", "sd", "prop", "count", "diff in means",
      "diff in medians", "diff in props", "Chisq", "F", "slope", "correlation",
      "t", "z", "ratio of props", "odds ratio"
    )
  ) {
    stop_glue(
      "You specified a string for `stat` that is not implemented. ",
      "Check your spelling and `?calculate` for current options."
    )
  }

  if (!("replicate" %in% names(x)) && !is_nuat(x, "generate")) {
    warning_glue(
      'A `generate()` step was not performed prior to `calculate()`. ',
      'Review carefully.'
    )
  }

  if (stat %in% c("F", "slope", "diff in means", "diff in medians")) {
    if (has_explanatory(x) && !is.numeric(response_variable(x))) {
      stop_glue(
        'The response variable of `{attr(x, "response")}` is not appropriate\n',
        "since '{stat}' is expecting the response variable to be numeric."
      )
    }
  }

  if (stat %in% c("diff in props", "ratio of props", "Chisq", "odds ratio")) {
    if (has_explanatory(x) && !is.factor(response_variable(x))) {
      stop_glue(
        'The response variable of `{attr(x, "response")}` is not appropriate\n',
        "since '{stat}' is expecting the response variable to be a factor."
      )
    }
  }

}

check_for_numeric_stat <- function(x, stat) {
  if (stat %in% c("mean", "median", "sum", "sd")) {
    col <- base::setdiff(names(x), "replicate")

    if (!is.numeric(x[[as.character(col)]])) {
      stop_glue(
        "Calculating a {stat} here is not appropriate\n",
        "since the `{col}` variable is not numeric."
      )
    }
  }
}

check_for_factor_stat <- function(x, stat, explanatory_variable) {
  if (stat %in% c("diff in means", "diff in medians", "diff in props", 
                  "F", "ratio of props", "odds ratio")) {
    if (!is.factor(explanatory_variable)) {
      stop_glue(
        'The explanatory variable of `{attr(x, "explanatory")}` is not ',
        "appropriate\n",
        "since '{stat}` is expecting the explanatory variable to be a factor."
      )
    }
  }
}

check_point_params <- function(x, stat) {
  param_names <- attr(attr(x, "params"), "names")
  hyp_text <- 'to be set in `hypothesize()`.'
  if (is_hypothesized(x)) {
    if (stat %in% c("mean", "median", "sd", "prop")) {
      if ((stat == "mean") && !("mu" %in% param_names)) {
        stop_glue('`stat == "mean"` requires `"mu"` {hyp_text}')
      }
      if (!(stat == "mean") && ("mu" %in% param_names)) {
        stop_glue('`"mu"` does not correspond to `stat = "{stat}"`.')
      }
      if ((stat == "median") && !("med" %in% param_names)) {
        stop_glue('`stat == "median"` requires `"med"` {hyp_text}')
      }
      if (!(stat == "median") && ("med" %in% param_names)) {
        stop_glue('`"med"` does not correspond to `stat = "{stat}"`.')
      }
      ## Tests unable to get to
      # if ((stat == "sigma") && !("sd" %in% param_names)) {
      #   stop_glue('`stat == "sd"` requires `"sigma"` {hyp_text}')
      # }
      if (!(stat == "sd") && ("sigma" %in% param_names)) {
        stop_glue('`"sigma"` does not correspond to `stat = "{stat}"`.')
      }

      ## Tests unable to get to
      # if ((stat == "prop") && !any(grepl("p.", param_names))) {
      #   stop_glue('`stat == "prop"` requires `"p"` {hyp_text}')
      # }
    }
  }
}

# This function checks for NaNs in the output of `calculate` and raises
# a message/warning/error depending on the context in which it was called.
check_for_nan <- function(x, context) {
  stat_is_nan <- is.nan(x[["stat"]])
  num_nans <- sum(stat_is_nan)
  # If there are no NaNs, continue on as normal :-)
  if (num_nans == 0) {
    return(x)
  }
  
  calc_ref <- "See ?calculate for more details"
  # If all of the data is NaN, raise an error
  if (num_nans == nrow(x)) {
    stop_glue("All calculated statistics were `NaN`. {calc_ref}.")
  }
  
  stats_were <- if (num_nans == 1) {"statistic was"} else {"statistics were"}
  num_nans_msg <- glue::glue("{num_nans} calculated {stats_were} `NaN`")
  
  if (context == "visualize") {
    # Raise a warning and plot the data with NaNs removed
    warning_glue(
      "{num_nans_msg}. `NaN`s have been omitted from visualization. {calc_ref}."
    )
    return(x[!stat_is_nan, ])
  } else if (context == "get_p_value") {
    # Raise an error
    stop_glue(
      "{num_nans_msg}. Simulation-based p-values are not well-defined for ",
      "null distributions with non-finite values. {calc_ref}."
    )
  }
}

# Helpers for hypothesize() -----------------------------------------------

match_null_hypothesis <- function(null) {
  null_hypothesis_types <- c("point", "independence")
  if(length(null) != 1) {
    stop_glue('You should specify exactly one type of null hypothesis.')
  }
  i <- pmatch(null, null_hypothesis_types)
  if(is.na(i)) {
    stop_glue('`null` should be either "point" or "independence".')
  }
  null_hypothesis_types[i]
}

sanitize_hypothesis_params_independence <- function(dots) {
  if (length(dots) > 0) {
    warning_glue(
      "Parameter values are not specified when testing that two variables are ",
      "independent."
    )
  }
  NULL
}

sanitize_hypothesis_params_point <- function(dots, x) {
  if(length(dots) != 1) {
    stop_glue("You must specify exactly one of `p`, `mu`, `med`, or `sigma`.")
  }
  if (!is.null(dots$p)) {
    dots$p <- sanitize_hypothesis_params_proportion(dots$p, x)
  }
  dots
}

sanitize_hypothesis_params_proportion <- function(p, x) {
  if(anyNA(p)) {
    stop_glue('`p` should not contain missing values.')
  }
  if(any(p < 0 | p > 1)) {
    stop_glue('`p` should only contain values between zero and one.')
  }
  if(length(p) == 1) {
    if(is_nuat(x, "success")) {
      stop_glue(
        "A point null regarding a proportion requires that `success` ",
        "be indicated in `specify()`."
      )
    }
    p <- c(p, 1 - p)
    names(p) <- get_success_then_response_levels(x)
  } else {
    if (sum(p) != 1) {
      stop_glue(
        "Make sure the hypothesized values for the `p` parameters sum to 1. ",
        "Please try again."
      )
    }
  }
  p
}


get_response_levels <- function(x) {
  as.character(unique(response_variable(x)))
}

get_success_then_response_levels <- function(x) {
  success_attr <- attr(x, "success")
  response_levels <- setdiff(
    get_response_levels(x),
    success_attr
  )
  c(success_attr, response_levels)
}

hypothesize_checks <- function(x, null) {
  # error: x is not a dataframe
  if (!sum(class(x) %in% c("data.frame", "tbl", "tbl_df", "grouped_df"))) {
    stop_glue("x must be a data.frame or tibble")
  }

  if (!has_response(x)) {
    stop_glue(
      "The response variable is not set. Make sure to `specify()` it first."
    )
  }

  if ((null == "independence") && !has_explanatory(x)) {
    stop_glue(
      'Please `specify()` an explanatory and a response variable when ',
      'testing\n',
      'a null hypothesis of `"independence"`.'
    )
  }
}

check_direction <- function(direction = c("less", "greater", "two_sided",
                                          "left", "right", "both",
                                          "two-sided", "two sided")) {
  check_type(direction, is.character)

  if (
    !(direction %in% c("less", "greater", "two_sided", "left", "right", 
                       "both", "two-sided", "two sided"))
  ) {
    stop_glue(
      'The provided value for `direction` is not appropriate. Possible values ',
      'are "less", "greater", "two-sided", "left", "right", "both", ',
      '"two_sided", or "two sided"'
    )
  }
}

check_obs_stat <- function(obs_stat) {
  if (!is.null(obs_stat)) {
    
    if ("data.frame" %in% class(obs_stat)) {
      check_type(obs_stat, is.data.frame)
      if ((nrow(obs_stat) != 1) || (ncol(obs_stat) != 1)) {
        warning_glue(
          "The first row and first column value of the given `obs_stat` will ",
          "be used."
        )
      }

      # [[1]] is used in case `stat` is not specified as name of 1x1
      obs_stat <- obs_stat[[1]][[1]]
      check_type(obs_stat, is.numeric)
    } else {
      check_type(obs_stat, is.numeric)
    }
  }

  obs_stat
}

#' Check object type
#'
#' Throw an error in case object is not of desired type.
#'
#' @param x An object to check.
#' @param predicate A function to perform check. A good idea is to use function
#'   named `is.*()` or `is_*()` with possible `<package>::` prefix.
#' @param type A string for desired type. If `NULL`, type is taken from parsing
#'   original name of supplied `predicate`: all alphanumeric with '_' and '.'
#'   characters (until the name end) after the first appearance of either `is.`
#'   or `is_`. In case of a doubt supply `type` explicitly.
#'
#' @examples
#' \dontrun{
#' x <- 1
#' check_type(x, is.numeric)
#' check_type(x, is.logical)
#' check_type(x, rlang::is_string, "character of length 1")
#' }
#'
#' @keywords internal
#' @noRd
check_type <- function(x, predicate, type = NULL) {
  x_name <- deparse(rlang::enexpr(x))
  if (is.null(type)) {
    predicate_name <- deparse(rlang::enexpr(predicate))
    type <- parse_type(predicate_name)
  }

  if (!isTRUE(predicate(x))) {
    # Not using "must be of type" because of 'tibble' and 'string' cases
    stop_glue("`{x_name}` must be '{type}', not '{get_type(x)}'.")
  }

  x
}

# This function is needed because `typeof()` on data frame returns "list"
get_type <- function(x) {
  if (is.data.frame(x)) {
    return("data.frame")
  }

  typeof(x)
}

parse_type <- function(f_name) {
  regmatches(
    f_name,
    regexec("is[_\\.]([[:alnum:]_\\.]+)$", f_name)
  )[[1]][2]
}

# Helpers for visualize() Utilities -----------------------------------------------

# a function for checking arguments to functions that are added as layers
# to visualize()d objects to make sure they weren't mistakenly piped
check_for_piped_visualize <- function(...) {
  
  is_ggplot_output <- vapply(list(...), ggplot2::is.ggplot, logical(1))
  
  if (any(is_ggplot_output)) {
    
    called_function <- sys.call(-1)[[1]]
    
    stop_glue(
      "It looks like you piped the result of `visualize()` into ",
      "`{called_function}()` (using `%>%`) rather than adding the result of ",
      "`{called_function}()` as a layer with `+`. Consider changing",
      "`%>%` to `+`."
    )
  }
  
  TRUE
}
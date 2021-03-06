rcmdcheck_comparison <- function(old, new) {
  stopifnot(is.list(old))
  stopifnot(inherits(new, "rcmdcheck"))

  # Generate data frame of problems
  old_df <- do.call(rbind, lapply(old, as.data.frame, which = "old"))
  new_df <- as.data.frame(new, which = "new")

  # For each problem, determine whether it's new (1), fixed (-1), or
  # unchanged (0/0.5).
  new_df$change <- ifelse(new_df$hash %in% old_df$hash, 0,    1)
  old_df$change <- ifelse(old_df$hash %in% new_df$hash, 0.5, -1)
  cmp_df <- rbind(old_df, new_df)

  # Compute overall status
  inst_fail <- install_failed(new_df$output) || install_failed(old_df$output)
  if (isTRUE(inst_fail)) {
    status <- "i"
  } else if (new$timeout) {
    status <- "t"
  } else if (sum(new_df$change == 1) == 0) {
    status <- "+"
  } else {
    status <- "-"
  }

  old_versions <- vapply(old, "[[", "version", FUN.VALUE = character(1))

  structure(
    list(
      package = new$package,
      versions = c(new$version, old_versions),
      status = status,
      old = old,
      new = new,
      cmp = cmp_df
    ),
    class = "rcmdcheck_comparison"
  )
}

install_failed <- function(stdout) {
  re_inst_fail <- "can be installed \\.\\.\\.\\s*ERROR\\s*Installation failed"
  any(grepl(re_inst_fail, stdout))
}

#' Print R CMD check result comparisons
#'
#' See [compare_checks()] and [compare_to_cran()].
#'
#' @param x R CMD check result comparison object.
#' @param header Whether to print the header. You can suppress the
#'   header if you want to use the printout as part of another object's
#'   printout.
#' @param ... Additional arguments, currently ignored.
#' @export
#' @importFrom crayon red green bold

print.rcmdcheck_comparison <- function(x, header = TRUE, ...) {
  if (header) {
    cat_head(
      "R CMD check comparison",
      paste0(x$package, " ", paste0(x$versions, collapse = " / "))
    )
  }

  status <- switch(x$status,
    "+" = green("OK"),
    "-" = red("BROKEN"),
    "i" = red("INSTALL FAILURE"),
    "t" = red("TIMEOUT")
  )
  cat_line("Status: ", bold(status))
  cat_line()

  print_comparison(x, -1, "Fixed")
  print_comparison(x, 0, "Still failing")
  print_comparison(x, 1, "Newly failing")

  invisible(x)
}

print_comparison <- function(x, change, title) {
  rows <- x$cmp[x$cmp$change == change, , drop = FALSE]
  if (nrow(rows) == 0) {
    return()
  }

  col <- if (change == -1) green else red
  sym <- if (change == -1) symbol$tick else symbol$cross

  cat_line(col(paste0(symbol$line, symbol$line, " ", title)))
  cat_line()
  cat_line(paste0(col(sym), " ", first_line(rows$output), "\n", collapse = ""))
}

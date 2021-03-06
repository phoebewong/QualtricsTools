#' Create a List of HTML Versions of the Results Tables
#'
#' @param blocks A list of the survey blocks, with the questions included in them.
#' @param flow A list of strings identifying the blocks in the order that they appear
#' within the survey.
#' @param include_block_headers A boolean (default: TRUE) parameter to indicate
#' whether or not there should be <h5> html headers inserted before each block with the
#' block's description.
#'
#' @return A list of HTML results tables for each question
create_html_results_tables <- function(blocks, flow, include_block_headers = TRUE) {

  # All the html tables will be saved into the tables list.
  tables <- list()
  tables[[1]] <- "<br>"
  options(stringsAsFactors = FALSE)

  # Determine the order of the block indices that we will use to
  # go through the blocks
  if (!missing(flow)) {
    # If the survey flow was provided, then use it to figure out
    # the block_ordering
    block_ordering <- list()
    for (h in flow) {
      matched_block <- sapply(blocks, function(x) {
        if ('ID' %in% names(x)) {
          return(identical(x[['ID']], h))
        } else
          return(FALSE)
      })
      if (table(matched_block)['TRUE'] == 1) {
        block_ordering <- c(block_ordering, which(matched_block))
      }
    }
  } else {
    # If no flow was provided, then just go in order through all the blocks
    block_ordering <- 1:length(blocks)
  }
  # Iterate over all non-empty blocks, insert headers if include_block_headers
  # == TRUE is specified, and for each question which is neither a Descriptive
  # Box nor marked with the qtSkip flag insert the question description rendered
  # by the question_description function.
  for (i in block_ordering) {
    # Check that the block isn't empty
    if ('BlockElements' %in% names(blocks[[i]])) {
      # Insert header
      if (include_block_headers)
        tables <-
          c(tables, paste0("<h5>", blocks[[i]][['Description']], "</h5><br>"))
      # Check that the BlockElement isn't empty
      if (length(blocks[[i]][['BlockElements']]) != 0) {
        for (j in 1:length(blocks[[i]][['BlockElements']])) {
          question <- blocks[[i]][['BlockElements']][[j]]
          # Check that the BlockElement is actually a question
          # containing a payload and question type.
          if ('Payload' %in% names(question) &&
              'QuestionType' %in% names(question[['Payload']])) {
            # Skip questions with question[['qtSkip']] == TRUE
            if (!'qtSkip' %in% names(question) ||
                question[['qtSkip']] != TRUE) {
              # If a question isn't a descriptive block, insert the question description for it
              if (question[['Payload']][['QuestionType']] != "DB") {
                tables <-
                  c(tables, question_description(question))
              }
            }
          }
        }
      }
    }
  }
  return(unlist(lapply(tables, paste)))
}


#' Create Question Description and Results Table Entry
#'
#' @param question A qualtrics survey question
#'
#' @return A list of HTML with a description table for the question,
#' and either the generated results, or a note saying why there are
#' no results.
question_description <- function(question) {
  tables <- list()

  # if the display logic is too long, write a note saying
  # that there is complex display logic, and to refer to the
  # Display Logic output.
  has_display_logic <- function(question) {
    has_dl <- FALSE
    if ('DisplayLogic' %in% names(question[['Payload']]))
      has_dl <- TRUE
    if ("Choices" %in% names(question[['Payload']])) {
      if (any(sapply(question[['Payload']][['Choices']], function(x)
        "DisplayLogic" %in% names(x)))) {
        has_dl <- TRUE
      }
    }
    if ("Answers" %in% names(question[['Payload']])) {
      if (any(sapply(question[['Payload']][['Answers']], function(x)
        "DisplayLogic" %in% names(x)))) {
        has_dl <- TRUE
      }
    }
    return(has_dl)
  }

  if (has_display_logic(question)) {
    display_logic <-
      list("Refer to the Display Logic panel for this question's logic.")
  } else display_logic <- list()

  # the question header is the data export tag, the question text (stripped of html),
  # and then display logic.
  description <-
    c(paste("Export Tag:", question[['Payload']][['DataExportTag']]),
      question[['Payload']][['QuestionTextClean']])

  # Check for notes, and include them where necessary
  if ('qtNotes' %in% names(question)) {
    description <- c(description, question[['qtNotes']])
  }

  # Append display logic after question notes
  description <- c(description, display_logic)


  # if there's no results table, append a message to the question
  # description accordingly.
  # - text entry -> "Question XX is a text entry question. See Appendix."
  # - otherwise -> "The results table for Question XX could not be
  #                 automatically processed."
  if ("Payload" %in% names(question)) {
    if (!"Table" %in% names(question) &&
        question[['Payload']][['QuestionType']] == "TE") {
      description <- c(
        description,
        paste0(
          "Question ",
          question[['Payload']][['DataExportTag']],
          " is a text entry question. See Appendix."
        )
      )
    } else if (!"Table" %in% names(question) &&
               !all(grepl("TEXT", names(question[['Responses']])))) {
      description <- c(
        description,
        paste0(
          "The results table for Question ",
          question[['Payload']][['DataExportTag']],
          " could not be automatically processed."
        )
      )
    }
  }

  # if the question isn't a text entry question, but has
  # columns in which "TEXT" appears, print one of the following
  # messages, depending on how many text entry columns are in the
  # question:
  #  1 - "This question has a text entry component. See Appendix."
  # >1 - "This question has multiple text entry components. See Appendices."
  if ("Payload" %in% names(question)) {
    if (question[['Payload']][['QuestionType']] != "TE") {
      if (length(grep("TEXT", names(question[['Responses']]))) == 1) {
        description <- c(description,
                         paste0("This question has a text entry component. See Appendix."))
      } else if (length(grep("TEXT", names(question[['Responses']]))) > 1) {
        description <- c(
          description,
          paste0(
            "This question has multiple text entry components. See Appendices."
          )
        )
      }
    }
  }

  # reshape the data into a data frame
  question_header <- do.call(rbind.data.frame,
                             t(description))

  # append the question description printed as an html table
  tables = c(tables, capture.output(
    print(
      xtable::xtable(question_header),
      include.colnames = FALSE,
      type = "html",
      caption.placement = "top",
      html.table.attributes = 'class="question_description data table table-bordered table-condensed"',
      include.rownames = FALSE
    )
  ))
  tables <- c(tables, "&nbsp;")

  # if the question has a results table, append it as an html table.
  if ("Table" %in% names(question)) {
    tables = c(tables, capture.output(
      print(
        xtable::xtable(question[['Table']]),
        type = "html",
        html.table.attributes = 'class="data table table-bordered table-condensed"',
        include.rownames = FALSE
      )
    ))
  }

  tables = c(tables, "<br><br>")
  return(tables)
}



#' Create HTML Tables for the Text Entry Questions
#'
#' This function creates an HTML string with tables
#' for each of the text entry questions and their text_responses.
#' The appendix_lettering function inside this function
#' is to create lettering for the tables in the style
#' of "A, B, ..., Z, AA, ..., ZZ" and so forth. The html
#' tables are created by looping through the blocks
#' and their contained question block elements. For each
#' question, if the question is a Text Entry question or
#' any of the response columns contain "TEXT" then a table
#' is created for those text_responses.
#'
#' @param blocks A list of blocks with block elements replaced
#' by the question with its paired responses.
#' @param original_first_rows This is the original first row of the
#' response set. If you have the original_first_rowss, you can
#' pass original_first_rowss[1,] to
#' @param flow is a list of blockIDs which is used to order the questions
#' in the output report.
#' @param n_threshold is the number of comments which must be present in order
#' for a coded comments table to appear.
#' @return an html string containing a title,
#' question text, and the text responses for each
#' text appendix.
text_appendices_table <-
  function(blocks,
           original_first_rows,
           flow,
           n_threshold = 15) {
    options(stringsAsFactors = FALSE)

    # Determine the ordering of the block indices that we will use to
    # iterate through the blocks.
    if (!missing(flow)) {
      # If flow was specified, use it to order the blocks and store the
      # blocks' ordering in the block_ordering list of indices.
      block_ordering <- list()
      for (h in flow) {
        # For each flow element, try and match it to a block.
        matched_block <- sapply(blocks, function(x) {
          if ('ID' %in% names(x)) {
            return(x[['ID']] == h)
          } else
            return(FALSE)
        })
        if (table(matched_block)['TRUE'] == 1) {
          block_ordering <- c(block_ordering, which(matched_block))
        }
      }
    } else {
      # If no flow is provided, go in order through the blocks.
      block_ordering <- 1:length(blocks)
    }

    # The tables list will store the HTML for the
    # text appendices generated. The e integer indexes
    # the appendices, and is incremented each time
    # an appendix is added to the tables list.
    tables <- list()
    e <- 1

    # In the following block of several nested loops and conditionals,
    # the most important iterators are: i, j, k, and e (described above).
    # i iterates from 1 to the number of blocks, j iterates for
    # each block from 1 to the number of block elements, and
    # whenever the question is not a text entry question k iterates
    # from 1 to the number of response columns.
    #
    # For each block, a block description is inserted as an <h5> header.
    # For each question with coded comments, the coded comments are inserted
    # if the number of comments is greater than the n_threshold parameter
    # and the question was not flagged with question[['qtSkip']]=TRUE.
    # If the question was not flagged with question[['verbatimSkip']]=TRUE,
    # then determine the appropriate function of table_text_entry,
    # table_no_respondents, and table_non_text_entry and use it to generate
    # the text appendix(es) for that question.

    # Loop over the blocks with i
    for (i in block_ordering) {
      # Only continue inspecting a block if it contains BlockElements
      if ('BlockElements' %in% names(blocks[[i]])) {
        # For each block with BlockElements, insert the block's
        # description as a header.
        tables <-
          c(tables, paste0("<h5>", blocks[[i]][['Description']], "</h5><br>"))
        # Loop over the BlockElements with j
        for (j in 1:length(blocks[[i]][['BlockElements']])) {

          question <- blocks[[i]][['BlockElements']][[j]]

          # qtSkip is a flag that can be inserted into a question for skipping
          # in text appendices and results tables reports. If it is absent or
          # not true, continue.
          if (!"qtSkip" %in% names(question) ||
              question[['qtSkip']] != TRUE) {

            # Table Coded Comments
            # If the question contains the 'CodedComments' element, then determine
            # how many comments were categorized by reading the entry in the
            # [[nrow_comments, 2]] position of the CodedComments dataframe.
            if ('CodedComments' %in% names(question)) {
              for (k in 1:length(question[['CodedComments']])) {
                nrow_comments = nrow(question[['CodedComments']][[k]][[2]])
                n_responses = question[['CodedComments']][[k]][[2]][[nrow_comments, 2]]
                n_responses = as.integer(n_responses)
                if (n_responses > n_threshold) {
                  tables <- c(
                    tables,
                    table_html_coded_comments(question,
                                              k,
                                              e,
                                              blocks,
                                              original_first_rows)
                  )
                }
              }
            }

            # Table Text Appendices
            # If verbatimSkip=TRUE is in the question, do not create any text appendices
            # for that question. If it is absent, continue.
            # Questions are then processed as text entry type questions or non text entry questions.
            if (
              # Check that 'verbatimSkip' != TRUE
              (!"verbatimSkip" %in% names(question) || question[['verbatimSkip']] != TRUE) &&
              # Check that the question has responses
              ('Responses' %in% names(question) && ncol(question[['Responses']]) > 0)) {

              # Store which columns are text entry response columns
              text_columns <-
                which(sapply(colnames(question[['Responses']]),
                             function(x)
                               grepl("TEXT", x)))

              # Text Entry Text Appendices
              if (question[['Payload']][['QuestionType']] == "TE") {

                # Clean Responses. Remove any responses which are -99 or
                # empty for an entire text entry question.
                text_responses <-
                  question[['Responses']]
                text_responses <-
                  as.data.frame(text_responses[!apply(text_responses, 1, function(x)
                    all(x %in% c(-99, ""))), ])

                # Ensure the response columns are named correctly after cleaning.
                colnames(text_responses) <- colnames(question[['Responses']])

                # If there are no responses, use the table_no_respondents
                # function to create a standardized no respondents table.
                if (nrow(text_responses) == 0) {
                  tables <-
                    c(tables, table_no_respondents(question, e))
                  e <- e + 1
                  # Skip the rest of the loop, and iterate j to move onto the
                  # next question.
                  next
                }

                # If there are valid responses, and the question type
                # as checked before is "TE" for Text Entry, then use the
                # table_text_entry function on the question to create its
                # text appendix.
                if (length(as.list(text_responses)) > 0) {
                  tables <- c(tables,
                              table_text_entry(question,
                                               text_responses,
                                               e,
                                               blocks,
                                               original_first_rows))
                  e <- e + 1
                }

              } else if (length(text_columns) > 0) {
                for (k in 1:length(text_columns)) {

                  # Clean Responses. Remove any responses which are -99 or
                  # empty for an entire text entry question.
                  text_responses <- question[['Responses']][text_columns[[k]]]
                  text_responses <-
                    as.data.frame(text_responses[!apply(text_responses, 1, function(x)
                      all(x %in% c(-99, ""))),])

                  # Ensure the response columns are named correctly after cleaning.
                  colnames(text_responses) <-
                    colnames(question[['Responses']][text_columns[[k]]])

                  # If there are no responses, use the table_no_respondents
                  # function to create a standardized no respondents table.
                  if (nrow(text_responses) == 0) {
                    tables <-
                      c(tables, table_no_respondents(question, e))
                    e <- e + 1
                    # Skip the rest of the loop, and iterate j to move onto the
                    # next question.
                    next
                  }

                  # Check if the number of Text Entry components to a multiple choice question
                  # is greater than one.
                  multiple_TE_components <- function(question) {
                    # Calculate the number of text entry components to a multiple choice question.
                    N_TE_components <- length(which(sapply(
                      question[['Payload']][['Choices']],
                      function(x) {
                        # Multiple Choice questions define their text entry components by labeling their
                        # choices as having the TextEntry property set to "true".
                        'TextEntry' %in% names(x) && x[['TextEntry']] == "true"
                      }
                    )))
                    return(N_TE_components > 1)
                  }

                  # Skip Single Answer questions with too many text entry components to table correctly
                  if (is_mc_single_answer(question) && multiple_TE_components(question)) {
                    tables <- c(tables, table_mcsa_multitext(question))
                    # Skip the rest of the loop, and iterate j to move onto the
                    # next question.
                    next
                  }

                  # Table Non-Text Entry Questions
                  # The logic before this ensures that the question is not of text entry type and contains
                  # valid responses. Now we use the generic table_non_text_entry question, meant for use on
                  # any column of open ended text responses. Note that while the table_non_text_entry
                  # function can table multiple columns of responses, we do not use this functionality here
                  # and instead pass a single column at a time, tabling each of the response columns as its
                  # own appendix.
                  tables <- c(
                    tables,
                    table_non_text_entry(question,
                                         text_responses,
                                         e,
                                         blocks,
                                         original_first_rows)
                  )
                  e <- e + 1
                }
              }
            }
          }
        }
      }
    }
    return(unlist(lapply(tables, paste)))
  }


#' Create a Message Stating Which Questions Weren't Automatically Tabled
#'
#' This is function is used in the Shiny app to tell users which questions weren't
#' automatically coded. This may be changed later to be more informative, or
#' to include this information elsewhere.
#'
#' @param questions A list of questions from a survey with results inserted into them.
#' @return A message stating for which questions could not have
#' results automatically generated.
uncodeable_questions_message <- function(questions) {
  # get all the questions that don't have tables, and
  # aren't a text entry question or a descriptive box.
  uncodeable_questions <- which(sapply(questions, function(x)
    ! ("Table" %in% names(x)) &&
      (x[['Payload']][['QuestionType']] != "TE") &&
      (x[['Payload']][['QuestionType']] != "DB") &&
      (x[['Payload']][['Selector']] != "TE")))

  # get the data export tags of the uncodeable questions
  uncodeable_questions <- sapply(uncodeable_questions, function(x)
    questions[[x]][['Payload']][['DataExportTag']])

  # write the message (ex. "The following questions could not be
  # automatically coded: Q1, Q2, ...")
  uncodeable_message <- ""
  if (length(uncodeable_questions) > 0) {
    uncodeable_questions <- paste(uncodeable_questions, collapse = ", ")
    uncodeable_message <-
      sprintf(
        "The following questions could not be automatically processed: %s",
        uncodeable_questions
      )
  } else {
    uncodeable_message <- "All questions were successfully processed!"
  }
  uncodeable_message <- paste0("<b>", uncodeable_message, "</b>")
  return(uncodeable_message)
}

#' Generate Tables for Each Question with Display Logic
#'
#' This function loops through every block, and checks if
#' each block element has display logic (and is not a descriptive box).
#' The descriptive boxes aren't included.
#' If it has display logic, it's inserted into the tables returned by
#' this function.
#'
#' @inheritParams create_html_results_tables
#' @return a list of html tables detailing the display logic for each question
#' containing display logic.
tabelize_display_logic <- function(blocks, flow) {
  # Determine the ordering of the block indices that we will use to
  # iterate through the blocks.
  if (!missing(flow)) {
    # If flow was specified, use it to order the blocks and store the
    # blocks' ordering in the block_ordering list of indices.
    block_ordering <- list()
    for (h in flow) {
      # For each flow element, try and match it to a block.
      matched_block <- sapply(blocks, function(x) {
        if ('ID' %in% names(x)) {
          return(x[['ID']] == h)
        } else
          return(FALSE)
      })
      if (table(matched_block)['TRUE'] == 1) {
        block_ordering <- c(block_ordering, which(matched_block))
      }
    }
  } else {
    # If no flow is provided, go in order through the blocks.
    block_ordering <- 1:length(blocks)
  }


  # all the html tables will be saved into the tables list.
  tables <- list()
  options(stringsAsFactors = FALSE)
  for (i in block_ordering) {
    if ('BlockElements' %in% names(blocks[[i]])) {
      for (j in 1:length(blocks[[i]][['BlockElements']])) {
        # if the display logic isn't trivial, include it.
        # each table should have the structure:
        #   - Data Export Tag
        #   - Question Text (stripped of HTML)
        #   - Display logic ...
        display_logic <-
          display_logic_from_question(blocks[[i]][['BlockElements']][[j]])
        if ("SkipLogic" %in% names(blocks[[i]][['BlockElements']][[j]][['Payload']])) {
          display_logic <- c(display_logic, "Skip Logic:")
          for (k in 1:length(blocks[[i]][['BlockElements']][[j]][['Payload']][['SkipLogic']])) {
            display_logic <-
              c(display_logic,
                clean_html(blocks[[i]][['BlockElements']][[j]][['Payload']][['SkipLogic']][[k]][['Description']]))
          }
        }
        if (length(display_logic) > 1) {
          display_logic <- do.call(rbind.data.frame, t(c(
            blocks[[i]][['BlockElements']][[j]][['Payload']][['DataExportTag']],
            blocks[[i]][['BlockElements']][[j]][['Payload']][['QuestionTextClean']],
            display_logic
          )))
          tables = c(tables, capture.output(
            print(
              xtable::xtable(display_logic),
              include.colnames = FALSE,
              type = "html",
              html.table.attributes =
                'class="survey_logic data table table-bordered table-condensed"',
              include.rownames = FALSE
            )
          ))

          tables <- c(tables, "<br>")
        }
      }
    }
  }
  return(unlist(lapply(tables, paste)))
}

#' Convert a Number into an Alphabetic Index (i.e. 27->AA)
#'
#' This function works recursively, at each step calculating each
#' place value of the given number in base 26. The suffix is used
#' to save the letters from the previous steps, and the base is
#' automatically assumed to be 26 for use with the English alphabet.
#'
#' @param number is a positive integer to be converted into
#' an alphabetic index.
#' @param base is a positive integer used to specify the size of the
#' alphabet used for alphabetic indexing.
#' @param suffix is appended to the output of the function, and is used
#' in the functions recursive steps to include the letters already computed
#' in previous steps.
#'
#' @examples
#' appendix_lettering(1000)
#' [1] "ALL"
#' sapply(1:60, appendix_lettering)
#' [1] "A"  "B"  "C"  "D"  "E"  "F"  "G"  "H"  "I"  "J"  "K"  "L"  "M"  "N"
#' [15] "O"  "P"  "Q"  "R"  "S"  "T"  "U"  "V"  "W"  "X"  "Y"  "Z"  "AA" "AB"
#' [29] "AC" "AD" "AE" "AF" "AG" "AH" "AI" "AJ" "AK" "AL" "AM" "AN" "AO" "AP"
#' [43] "AQ" "AR" "AS" "AT" "AU" "AV" "AW" "AX" "AY" "AZ" "BA" "BB" "BC" "BD"
#' [57] "BE" "BF" "BG" "BH"
appendix_lettering <- function(number, base = 26, suffix = "") {
  number1 <- number - 1
  digit <- number1 %% base
  number1 <- number1 %/% base
  suffix <- paste0(LETTERS[digit + 1], suffix)
  if (number1 > 0) Recall(number1, base, suffix) else suffix
}


#' Create a Text Appendix for Coded Comments
#'
#' This returns a list containing two tables: the question's description table and the categorical
#' breakdown of the responses into the coded comments' categories. The description includes an
#' "Appendix ##" title, the question text, and a tag which states the following appendix is
#' "Coded Comments." The coded comments table has two columns: the "Responses" and "N", in which
#' the categories and their frequencies are listed.
#'
#' @param question is the question to which the coded comments belong.
#' @param cc_index is the index of the coded comments to appendicize.
#' @param appendix_e is the number of the appendix in the text appendices report.
#' @param blocks is the list of survey blocks.
#' @param original_first_row is the original header information from the CSV response data.
table_html_coded_comments <-
  function(question,
           cc_index,
           appendix_e,
           blocks,
           original_first_row) {
    response_column <- question[['CodedComments']][[cc_index]][[1]]
    choice_text <-
      choice_text_from_response_column(response_column, original_first_row, blocks)
    if (choice_text != "") {
      question_text <-
        paste0(question[['Payload']][['QuestionTextClean']],
               "-",
               choice_text)
    } else {
      question_text <- question[['Payload']][['QuestionTextClean']]
    }
    text_appendix_header <-
      c(paste0("Appendix ", appendix_lettering(appendix_e)),
        question_text,
        "Coded Comments",
        "")

    text_appendix_header <- as.data.frame(text_appendix_header)
    text_appendix_header <-
      do.call("cbind", replicate(2, text_appendix_header, simplify = FALSE))
    coded_comment_names <-
      c(paste0('Export Tag: ', question[['Payload']][['DataExportTag']]),
        paste0('Export Tag: ', question[['Payload']][['DataExportTag']], " "))
    colnames(text_appendix_header) <- coded_comment_names
    colnames(question[['CodedComments']][[cc_index]][[2]]) <-
      coded_comment_names
    response_n <- t(as.data.frame(c("Responses", "N")))
    colnames(response_n) <- coded_comment_names
    coded_comments_table <-
      rbind(response_n, question[['CodedComments']][[cc_index]][[2]])
    text_appendix <- rbind(text_appendix_header, coded_comments_table)
    tables <- list()
    tables <-
      c(tables, capture.output(
        print(
          xtable::xtable(text_appendix),
          type = "html",
          html.table.attributes = 'class="text_appendices data table table-bordered table-condensed"',
          include.rownames = FALSE
        )
      ))

    tables <- c(tables, "<br>")
    return(tables)
  }


#' Create a standard "No Respondents answered this question" text appendix
#'
#' This function returns a standardized html table intended to go into a
#' document of text appendices indicating that there were no respondents
#' who answered the given text entry question.
#'
#' @param question is the question for which the text appendix is being created.
#' @param appendix_e is the number of the appendix in the text appendices report.
table_no_respondents <- function(question, appendix_e) {
  No_Respondents <-
    c(
      paste0("Appendix ", appendix_lettering(appendix_e)),
      question[['Payload']][['QuestionTextClean']],
      "Verbatim responses -- these have not been edited in any way.",
      "",
      "No respondents answered this question"
    )
  No_Respondents <- as.data.frame(No_Respondents)
  colnames(No_Respondents)[1] <-
    paste0('Export Tag: ', question[['Payload']][['DataExportTag']])
  tables <- list()
  tables <-
    c(tables, capture.output(
      print(
        xtable::xtable(No_Respondents),
        type = "html",
        html.table.attributes = 'class="text_appendices data table table-bordered table-condensed"',
        include.rownames = FALSE
      )
    ))
  tables <- c(tables, "<br>")
  return(tables)
}


#' Create Text Appendices for Text Entry Type Questions
#'
#' The `table_text_entry` function creates a text appendix with as many
#' columns as there are text entry components to the given question and fills
#' them with the responses from each respondent across the rows.
#'
#' @param question is the question for which the text appendix is being created.
#' @param responses is a data frame of text responses to the question given.
#' @param appendix_e is the number of the appendix in the text appendices report.
#' @param blocks is the list of survey blocks.
#' @param original_first_row is the original header information from the CSV response data.
table_text_entry <-
  function(question,
           text_responses,
           appendix_e,
           blocks,
           original_first_row) {
    response_n <- paste0("Responses: (", nrow(text_responses), ")")

    # generate the headers for each column
    text_appendix_header <- list()
    for (l in 1:ncol(text_responses)) {
      choice_text <-
        choice_text_from_response_column(colnames(text_responses)[[l]], original_first_row, blocks)
      if (choice_text != "") {
        question_text <-
          paste0(question[['Payload']][['QuestionTextClean']],
                 "-",
                 choice_text)
      } else {
        question_text <- question[['Payload']][['QuestionTextClean']]
      }
      text_appendix_header[[l]] <-
        c(
          paste0("Appendix ", appendix_lettering(appendix_e)),
          question_text,
          "Verbatim responses -- these have not been edited in any way.",
          "",
          response_n
        )
    }
    text_appendix_header <-
      do.call(cbind.data.frame, text_appendix_header)

    # bind the header and responses together to make the text appendix
    colnames(text_appendix_header) <- colnames(text_responses)
    text_appendix <- rbind(text_appendix_header, text_responses)

    # set colnames as response column names
    colnames(text_appendix) <-
      sapply(colnames(text_responses), function (x)
        paste0('Export Tag: ', x))

    tables <- list()
    # turn the text appendix into an html table, and add it to the tables list
    tables <-
      c(tables, capture.output(
        print(
          xtable::xtable(text_appendix),
          type = "html",
          html.table.attributes = 'class="text_appendices data table table-bordered table-condensed"',
          include.rownames = FALSE
        )
      ))
    tables <- c(tables, "<br>")
    return(tables)
  }

#' Create Text Appendices for Non-Text Entry Type Questions
#'
#' This function creates text appendices, with a description table and
#' responses table, for questions which are not text-entry type questions.
#' The description table contains a text appendix title, like "Appendix A"
#' and the responses are tabled verbatim beneath it.
#'
#' @param question is the question for which the text appendix is being created.
#' @param responses is a data frame of text responses to the question given.
#' @param appendix_e is the number of the appendix in the text appendices report.
#' @inheritParams text_appendices_table
table_non_text_entry <- function(question,
                                 text_responses,
                                 appendix_e,
                                 blocks,
                                 original_first_row) {
  response_n <- paste0("Responses: (", nrow(text_responses), ")")

  # generate the header for the text appendix
  text_appendix_header <- list()
  for (l in 1:ncol(text_responses)) {
    choice_text <-
      choice_text_from_response_column(colnames(text_responses)[[l]], original_first_row, blocks)
    if (choice_text != "") {
      question_text <-
        paste0(question[['Payload']][['QuestionTextClean']],
               "-",
               choice_text)
    } else {
      question_text <- question[['Payload']][['QuestionTextClean']]
    }
    text_appendix_header[[l]] <-
      c(
        paste0("Appendix ", appendix_lettering(appendix_e)),
        question_text,
        "Verbatim responses -- these have not been edited in any way.",
        "",
        response_n
      )
  }
  text_appendix_header <-
    do.call(cbind.data.frame, text_appendix_header)

  # bind the header and responses together to make the text appendix
  colnames(text_appendix_header) <- colnames(text_responses)
  text_appendix <- rbind(text_appendix_header, text_responses)

  # update the response columns names to have the "Export Tag: " prepended
  colnames(text_appendix) <-
    sapply(colnames(text_responses), function(x)
      paste0('Export Tag: ', x))

  tables <- list()
  # turn the text appendix into an html table, and add it to the tables list
  tables <-
    c(tables, capture.output(
      print(
        xtable::xtable(text_appendix),
        type = "html",
        html.table.attributes = 'class="text_appendices data table table-bordered table-condensed"',
        include.rownames = FALSE
      )
    ))
  tables <- c(tables, "<br>")
  return(tables)
}

#' Create a message stating MCSA questions with Multiple Text Entry components
#' can't be automatically processed for text appendices.
#' @inheritParams question_description
table_mcsa_multitext <- function(question) {
  question_message <-
    c(
      question[['Payload']][['QuestionTextClean']],
      "",
      "This question could not be automatically processed because the CSV response dataset
      does not separate the responses for each text entry component of this question."
    )
  question_message <- as.data.frame(question_message)
  colnames(question_message)[1] <-
    paste0('Export Tag: ', question[['Payload']][['DataExportTag']])
  output_html <- capture.output(
      print(
        xtable::xtable(question_message),
        type = "html",
        html.table.attributes =
          'class="text_appendices data table table-bordered table-condensed"',
        include.rownames =
          FALSE
      )
    )
  output_html = paste(output_html, "<br>")
  return(output_html)
}

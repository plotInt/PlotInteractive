#' Interactive Plotting for Functional-on-Scalar Regressions
#' 
#' Produces an interactive plot illustrating a function-on-scalar 
#' regression analysis. 
#' 
#' @param fosr.obj fosr object to be plotted. 
#' @param xlab x axis label
#' @param ylab y axis label
#' @param title plot title
#' 
#' @author Jeff Goldsmith \email{jeff.goldsmith@@columbia.edu}, 
#' Julia Wrobel \email{jw3134@@cumc.columbia.edu}
#' 
#' @seealso \code{\link{plot_interactive}}
#' @import shiny
#' @import ggplot2
#' @importFrom reshape2 melt
#' @export
#' 
plot_interactive.fosr = function(fosr.obj, xlab = "", ylab="", title = "") {
    
  ################################
  ## code for processing tabs
  ################################
  
  p = dim(fosr.obj$beta.hat)[1]
  D = dim(fosr.obj$beta.hat)[2]
  grid = 1:D
  
  ## Tab 1: covariate choice
  covar.list = names(attributes(terms(fosr.obj$terms))$dataClasses)
  covar.list[1] = "None"
  covarInputValues = 1:length(covar.list)
  names(covarInputValues) = covar.list
  
  ## Tab 2: fitted values
  pred.list = names(attributes(terms(fosr.obj$terms))$dataClasses)[-1]
  calls <- vector("list", length(pred.list))
  for(i in 1:length(pred.list)){
    calls[[i]] =  eval(createInputCall(pred.list[i], get(pred.list[i], fosr.obj$data) ))
  }  
  
  ## Tab 3: coefficient functions
  coef.list = colnames(model.matrix(fosr.obj$terms, fosr.obj$data[1,]))
  coefInputValues = 1:p
  names(coefInputValues) = coef.list
  
  #################################
  ## App
  #################################
  
  shinyApp(
    
  #################################
  ## UI
  #################################
    
    ui = navbarPage(title = strong(style = "color: #ACD6FF; padding: 0px 0px 10px 10px; opacity: 0.95; ", "FoSR Plot"), windowTitle = "PlotInteractive", 
                    collapsible = FALSE, id = "nav",
                    inverse = TRUE, header = NULL,
                    tabPanel("Observed Data", icon = icon("stats", lib = "glyphicon"),
                             column(3, 
                                    helpText("Observed response data, colored according to the covariate selected below."), hr(),
                                    selectInput("CovarChoice", label = ("Select Covariate"), choices = covarInputValues, selected = 1)
                                    ),
                             column(9, h4("Observed Data"), 
                                    plotOutput('ObsDataPlot')
                                    )
                            ),
                    tabPanel("Fitted Values", icon = icon("line-chart"),
                             column(3,
                                    helpText("Fitted response curve for a subject with covariate values specified below."), hr(),
                                    eval(calls)
                                   ),
                             column(9, h4("Fitted Response Curve"), 
                                   plotOutput('FittedValPlot')
                                   )
                            ),
                    tabPanel("Coefficient Functions", icon = icon("area-chart"),
                             column(3, 
                                    helpText("Coefficient function and confidence bounds for the predictor selected below"), hr(),
                                    selectInput("CoefChoice", label = ("Select Predictor"), choices = coefInputValues, selected = 1)
                                    ),
                             column(9, h4("Coefficient Function"), 
                                    plotOutput('CoefFunc')
                                    )     
                            ),
                    tabPanel("Residuals", icon = icon("medkit"),
                             column(3, 
                                    helpText("Plot of residual curves."), hr(),
                                    #checkboxInput("outliers", label="Show median and outliers"),
                                    radioButtons("residOptions", label="Plot Options", 
                                                 choices = list("None"=1, "Show Median and Outliers"=2,"Rainbowize by Depth"=3), 
                                                 selected=1),
                                    helpText("If 'Show Outliers' is selected, the median and outlying curves are shown 
                                             in blue and red respectively. If 'Rainbowize' is selected, curves are ordered by band depth
                                             with most outlying curves shown in red and curves closest to the median shown in violet")
                                    ),
                             column(9, h4("Residuals"), 
                                    plotOutput('resid')
                                    )     
                            )
                    ),
    
    #################################
    ## Server
    #################################

    server = function(input, output){
      
      #################################
      ## Code for observed data tab
      #################################
      
      dataInputObsData <- reactive({
        y.obs = fosr.obj$data[,names(attributes(terms(fosr.obj$terms))$dataClasses)[1]]
        colnames(y.obs) = grid
        y.obs.m = melt(y.obs)
        colnames(y.obs.m) = c("subj", "grid", "value")
        
        CovarChoice = as.numeric(input$CovarChoice)
        selected = covar.list[CovarChoice]
        if(selected == "None") {
          y.obs.m$covariate = NULL
        } else {
          y.obs.m$covariate = rep(fosr.obj$data[,selected], length(grid))
        }
        y.obs.m
      })
      
      output$ObsDataPlot <- renderPlot(
        if(is.null(dataInputObsData()$covariate)){
          ggplot(dataInputObsData(), aes(x=grid, y=value, group = subj)) + geom_line(alpha = .3, color="black") +
            theme_bw() + xlab("") + ylab("") 
        } else {
          ggplot(dataInputObsData(), aes(x=grid, y=value, group = subj, color = covariate)) + geom_line(alpha = .3) +
            theme_bw() + xlab("") + ylab("") + theme(legend.position="bottom", legend.title=element_blank())
        }
      )
      
      #################################
      ## Code for FittedValues Tab
      #################################
      
      dataInputFittedVal <- reactive({
        
        variables = sapply(pred.list, function(u) {input[[u]]})
        
        input.data = fosr.obj$data[1,]
        
        reassign = function(var, newdata){
          if(is.numeric(fosr.obj$data[,var])){ 
            var.value = as.numeric(newdata[var]) 
            #          } else if(is.factor(fosr.obj$data[,var]) & length(levels(fosr.obj$data[,var])) <=2){ 
            #            var.value = factor(levels(fosr.obj$data[,var])[newdata[var]+1], levels = levels(fosr.obj$data[,var])) 
          } else if(is.factor(fosr.obj$data[,var])){ 
            var.value = factor(newdata[var], levels = levels(fosr.obj$data[,var])) 
          }
          var.value
        }
        
        input.data[,pred.list] = lapply(pred.list, reassign, variables)
        
        X.design = t(matrix(model.matrix(fosr.obj$terms, input.data)))
        fit.vals = as.vector(X.design %*% fosr.obj$beta.hat)
        data.frame(grid = grid,
                   fit.vals = fit.vals)
      })
      
      output$FittedValPlot <- renderPlot(
        ggplot(dataInputFittedVal(), aes(x = grid, y = fit.vals)) + geom_line(lwd=1) + theme_bw() +
          xlab(xlab) + ylab(ylab) + ylim(c(.9, 1.1) * range(fosr.obj$Yhat))
      )
      
      #################################
      ## Code for CoefFunc Tab
      #################################
      
      dataInputCoefFunc <- reactive({
        CoefChoice = as.numeric(input$CoefChoice)
        data.frame(grid = grid,
                   coef = fosr.obj$beta.hat[CoefChoice,],
                   UB =  fosr.obj$beta.UB[CoefChoice,],
                   LB = fosr.obj$beta.LB[CoefChoice,])
      })      
      
      output$CoefFunc <- renderPlot(
        ggplot(dataInputCoefFunc(), aes(x=grid, y=coef))+geom_line(linetype=1, lwd=1.5, color="black")+
          geom_line(data = dataInputCoefFunc(), aes(y=UB), color = "blue") +
          geom_line(data = dataInputCoefFunc(), aes(y=LB), color = "blue")+
          theme_bw() + xlab("") + ylab("") 
      )
      
      
      
      
      #################################
      ## Code for Residual plot
      #################################

      response = fosr.obj$data[,names(attributes(terms(fosr.obj$terms))$dataClasses)[1]]
      resid = response - fosr.obj$Yhat
      colnames(resid) = grid
      outs = outliers(resid, 1.5) # detects outliers
      resid.m = melt(resid)
      colnames(resid.m) = c("subj", "grid", "residual")
      resid.m = resid.m[order(resid.m$subj),]
      resid.m$depths = rep(outs$depth, each = dim(resid)[2])
      resid.m = resid.m[order(resid.m$depths, decreasing = FALSE),]
      resid.m$depth.rank = rep(1:dim(resid)[1], each=dim(resid)[2])
      
      
      # residuals for outliers

      resid.outs.m = melt(outs$outcurves)
      colnames(resid.outs.m) = c("subj", "grid", "residual")
      
      # residuals for median curve
      resid.med.m = melt(outs$medcurve)
      colnames(resid.med.m) = c("subj", "grid", "residual")
      
       plotInputResid <- reactive({
        residPlot = ggplot(resid.m, aes(x=grid, y=residual, group = subj))+ theme_bw() + geom_line(alpha = .3, color="black") 
        
        if(input$residOptions==2 & dim(outs$outcurves)[1]!= 0){residPlot=residPlot+
                                   geom_line(data=resid.outs.m, aes(x=grid, y=residual, group=subj, color="outliers"))+
                                   geom_line(data=resid.med.m, aes(x=grid, y=residual, group=subj, color = "median"))+
                                   scale_colour_manual("", values = c("outliers"="red", "median"="blue"), guide = FALSE)
                                   #theme(legend.position="bottom")
                                   
        } 
        else if(input$residOptions==2 & dim(outs$outcurves)[1]== 0){residPlot=residPlot+
                                   geom_line(data=resid.med.m, aes(x=grid, y=residual, group=subj, color = "median"))+
                                   scale_colour_manual("", values = c("median"="blue"), guide=FALSE)
                                                              
        } 
        
        else if (input$residOptions == 3){residPlot = ggplot(resid.m, aes(x=grid, y=residual, group = subj)) +
                                             geom_line(aes(color=factor(depth.rank))) + theme_bw()+ theme(legend.position="none")}
        residPlot  + xlab("") + ylab("")
      })   
      
      
      
      output$resid <- renderPlot(
        plotInputResid() 

      )
      
       
      
      ## add subject number
      
    } ## end server
  )
}


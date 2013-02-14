$(document).ready ->
  # new project form
  new SmartForm $('.new_project'), (project) -> window.location = project.url

  # breadcrumbs stats growing and shrinking
  open_widths = ($(div).width() for div in $('#breadcrumbs-stats>div'))
  $('#breadcrumbs-stats>div').removeClass 'shown'
  closed_widths = ($(div).width() for div in $('#breadcrumbs-stats>div'))
  $('#breadcrumbs-stats>div').each (index, div) ->
    $(div).hover (->
      $(div).stop(true).animate {width: open_widths[index]}, -> $(div).addClass 'shown'
    ), ->
      $(div).removeClass 'shown'
      $(div).stop(true).animate {width: closed_widths[index]}
#
#    after_enter_func = -> $(div).addClass('shown').mouseleave leave_func
#    after_leave_func = -> $(div).mouseenter enter_func
#    enter_func = ->
#      $(div).unbind('mouseenter').mouseleave ->
#        $(div).stop().css 'width', closed_widths[index]
#        after_leave_func()
#      $(div).animate {width: open_widths[index]},  after_enter_func
#    leave_func = ->
#      $(div).removeClass 'shown'
#      $(div).unbind('mouseleave').mouseenter ->
#        $(div).stop(false, true)
#        after_enter_func()
#      $(div).animate {width: closed_widths[index]}, after_leave_func
#
#    $(div).mouseenter enter_func

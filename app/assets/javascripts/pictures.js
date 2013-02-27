$(function(){
  $("#reset-button").click(function(){
    $("#url").val("");
    $("#title").val("");
  });

  $("#url").click(function(){
    $("#url").val("");
    $("#title").val("");
  });

  $("body").click(function(){
    //alert("hello");
    $("#dialog").dialog();
  });
});


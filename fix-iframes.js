document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll("iframe").forEach(frame => {
    const src = frame.getAttribute("src");
    // אם src מכיל github.io – החלף אותו ל־shamze.com
    if (src && src.includes("yossidisk.github.io")) {
      frame.src = src.replace(
        /^https:\/\/yossidisk\.github\.io/,
        "https://shamze.com"
      );
    }
  });
});

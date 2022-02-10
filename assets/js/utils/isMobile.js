export default function isMobile(mobileMaxWidth = 480) {
  const UA =
    /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(
      window.navigator.userAgent
    );

  return (
    UA ||
    window?.matchMedia(`(max-width: ${mobileMaxWidth}px)`)?.matches ||
    false
  );
}

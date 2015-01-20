;;; sunshine.el --- Provide weather and forecast information.
;;; Commentary:
;;
;; Use OpenWeatherMap's API to provide current weather and forecast information within Emacs!
;;
;; THINGS TO DO:
;; * Build the full week's worth of weather data in the output.
;; * Format it with some propertization.
;; * Make the new buffer uneditable.
;; * Create a key map (related to above?), at least for quit.
;; * Add icons.
;;
;;; Code:
(require 'cl-macs)
(require 'url)
(require 'url-cache)
(require 'time-date)
(require 'json)

;;; Declaring this is polite, though this var is created later by url-http.
(defvar url-http-end-of-headers)

(defun sunshine-extract-response (buf)
  "Extract the JSON response from the buffer returned by url-http.
Provide the buffer as BUF."
  (with-current-buffer buf
    (goto-char url-http-end-of-headers)
    (prog1 (json-read)
      (kill-buffer))))

(defun sunshine-get-forecast (query &optional units)
  "Get forecast data from OpenWeatherMap's API.
Provide a location as QUERY and optionally the preferred unit
of measurement as UNITS (e.g. 'metric' or 'imperial')."
  (let* ((url (concat "http://api.openweathermap.org/data/2.5/forecast/daily?q="
                      query
                      "&mode=json&units=imperial&cnt=5"))
         (weather-json-buffer (url-retrieve-synchronously url)))
    (sunshine-build-simple-forecast
     (sunshine-extract-response weather-json-buffer))))

(defun sunshine-build-simple-forecast (fc-data)
  "Build a simple, legible forecast from FC-DATA.
FC-DATA is the raw forecast data resulting from calling json-read on the
forecast results."
  (cl-loop for day across (cdr (assoc 'list fc-data)) collect
           (list
            (cons 'date (format-time-string "%A %h %e" (seconds-to-time (cdr (assoc 'dt day)))))
            (cons 'desc (cdr (assoc 'main (elt (cdr (assoc 'weather day)) 0))))
            (cons 'temp (cdr (assoc 'temp day)))
            (cons 'pressure (cdr (assoc 'pressure day))))))

(defun sunshine-open-forecast-window ()
  "Display the forecast."
  (let ((buf (get-buffer-create "*Forecast*")))
    (pop-to-buffer buf)
    (erase-buffer)))

(defun sunshine-forecast ()
  "The main entry into Sunshine; display the forecast in a window."
  (interactive)
  (sunshine-open-forecast-window)
  (sunshine-draw-forecast
    (sunshine-get-forecast "Brookline,MA")))

(defun sunshine-draw-forecast (forecast)
  "Draw FORECAST in pretty ASCII."
  (let ((hline (concat "+"
                       (mapconcat 'identity
                                  (cl-loop for i from 1 to 5 collect
                                           (concat (make-string 18 ?-)
                                                   "+")) "")
                       "\n")))
    (insert (concat hline "|"))
    (while forecast
      (let* ((day (car forecast))
             (date (cdr (assoc 'date day)))
             (desc (cdr (assoc 'desc day)))
             (high (cdr (assoc 'max (cdr (assoc 'temp day)))))
             (low (cdr (assoc 'min (cdr (assoc 'temp day))))))
        (insert (sunshine-pad-or-trunc date 18 1 "\u22EF") "|\n"
                (sunshine-pad-or-trunc desc 18 1 "\u22EF") "|\n"
                (number-to-string low) "\n"
                (number-to-string high) "|\n"))
      (setq forecast (cdr forecast)))
    (insert (concat "\n" hline))))

(defun sunshine-pad-or-trunc (string column-width &optional pad trunc-string)
  "Pad or truncate STRING to fit in COLUMN-WIDTH.
Optionally, add PAD spaces before and after STRING, and if STRING exceeds the
available width, truncate it to fit, optionally appending TRUNC-STRING."
  (let* ((actual-width (- column-width (if pad (* pad 2) 0)))
         (display-string (if (> (length string) actual-width)
                             ;; If string exceeds size, truncate.
                             (concat (substring string 0 (- actual-width (if trunc-string (length trunc-string) 0))) trunc-string)
                           ;; Otherwise, pad.
                           (concat string (make-string (- actual-width (length string)) ? )))))
    (concat (if pad (make-string pad ? ))
            display-string
            (if pad (make-string pad ? )))))

(provide 'sunshine)
;;; sunshine.el ends here
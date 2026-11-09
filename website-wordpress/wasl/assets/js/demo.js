/* Wasl pickup-code demo — delivery #1044, code K7M2.
   No network, no storage: purely a front-end demo. */
(function () {
	'use strict';

	var input = document.getElementById('wasl-code-input');
	var btn = document.getElementById('wasl-code-btn');
	var msg = document.getElementById('wasl-code-msg');
	if (!input || !btn || !msg) {
		return;
	}

	var CODE = 'K7M2';
	var hint = msg.textContent;

	function check() {
		var val = (input.value || '').toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 4);
		input.value = val;
		if (val.length < 4) {
			msg.textContent = 'Enter the 4-character code from the label.';
			msg.classList.remove('ok', 'err');
			return;
		}
		if (val === CODE) {
			msg.textContent = '✓ Pickup confirmed — driver Hiba is on the road. Arriving in 8 min.';
			msg.classList.add('ok');
			msg.classList.remove('err');
			input.style.borderColor = '#4ade80';
		} else {
			msg.textContent = '✕ Wrong code — pickup stays locked. Check the label and try again.';
			msg.classList.add('err');
			msg.classList.remove('ok');
			input.style.borderColor = '#f87171';
		}
	}

	btn.addEventListener('click', check);
	input.addEventListener('keydown', function (e) {
		if (e.key === 'Enter') {
			e.preventDefault();
			check();
		}
	});
	input.addEventListener('input', function () {
		input.value = input.value.toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 4);
		msg.classList.remove('ok', 'err');
		input.style.borderColor = '';
		if (!input.value) {
			msg.textContent = hint;
		}
	});
})();

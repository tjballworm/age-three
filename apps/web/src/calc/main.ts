import { mount } from 'svelte';
import './calc.css';
import Calc from './Calc.svelte';

export default mount(Calc, { target: document.getElementById('calc')! });

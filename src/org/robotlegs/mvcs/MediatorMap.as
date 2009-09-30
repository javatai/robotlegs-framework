/*
 * Copyright (c) 2009 the original author or authors
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

package org.robotlegs.mvcs
{
	import flash.display.DisplayObject;
	import flash.events.Event;
	import flash.utils.Dictionary;
	
	import org.as3commons.logging.ILogger;
	import org.as3commons.logging.impl.NullLogger;
	import org.robotlegs.core.IInjector;
	import org.robotlegs.core.IMediator;
	import org.robotlegs.core.IMediatorMap;
	import org.robotlegs.core.IReflector;
	import org.robotlegs.utils.DelayedFunctionQueue;
	
	/**
	 * Default MVCS <code>IMediatorMap</code> implementation
	 */
	public class MediatorMap implements IMediatorMap
	{
		protected var contextView:DisplayObject;
		protected var injector:IInjector;
		protected var logger:ILogger;
		protected var reflector:IReflector;
		protected var useCapture:Boolean;
		
		protected var mediatorByView:Dictionary;
		protected var mappingConfigByView:Dictionary;
		protected var mappingConfigByViewClassName:Dictionary;
		protected var localViewClassByViewClassName:Dictionary;
		
		/**
		 * Creates a new <code>MediatorMap</code> object
		 * @param contextView The root view node of the context. The context will listen for ADDED_TO_STAGE events on this node
		 * @param injector An <code>IInjector</code> to use for this context
		 * @param reflector An <code>IReflector</code> to use for this context
		 * @param useCapture Optional, change at your peril!
		 */
		public function MediatorMap(contextView:DisplayObject, injector:IInjector, reflector:IReflector, logger:ILogger = null, useCapture:Boolean = true)
		{
			this.contextView = contextView;
			this.injector = injector;
			this.reflector = reflector;
			this.logger = logger ? logger : new NullLogger();
			this.useCapture = useCapture;
			
			this.mediatorByView = new Dictionary(true);
			this.mappingConfigByView = new Dictionary(true);
			this.mappingConfigByViewClassName = new Dictionary(false);
			
			initializeListeners();
		}
		
		/**
		 * @inheritDoc
		 */
		public function map(viewClassOrName:*, mediatorClass:Class, autoRegister:Boolean = true, autoRemove:Boolean = true):void
		{
			var message:String;
			var viewClassName:String = reflector.getFQCN(viewClassOrName);
			if (mappingConfigByViewClassName[viewClassName] != null)
			{
				message = ContextError.E_MAP_EXISTS + ' - ' + mediatorClass;
				logger.error(message);
				throw new ContextError(message);
			}
			if (reflector.classExtendsOrImplements(mediatorClass, IMediator) == false)
			{
				message = ContextError.E_MAP_NOIMPL + ' - ' + mediatorClass
				logger.error(message);
				throw new ContextError(message);
			}
			var config:MappingConfig = new MappingConfig();
			config.mediatorClass = mediatorClass;
			config.autoRegister = autoRegister;
			config.autoRemove = autoRemove;
			if (viewClassOrName is Class)
			{
				config.typedViewClass = viewClassOrName;
			}
			mappingConfigByViewClassName[viewClassName] = config;
			logger.info('Mediator Mapped: (' + mediatorClass + ') to concrete view class (' + viewClassName + ')');
		}
		
		/**
		 * @inheritDoc
		 */
		public function mapModule(moduleClassName:String, localModuleClass:Class, mediatorClass:Class, autoRegister:Boolean = true, autoRemove:Boolean = true):void
		{
			map(moduleClassName, mediatorClass, autoRegister, autoRemove);
			var config:MappingConfig = mappingConfigByViewClassName[moduleClassName];
			config.typedViewClass = localModuleClass;
			logger.info('Module Mapping: (' + mediatorClass + ') will be injected with local type (' + localModuleClass + ')');
		}
		
		/**
		 * @inheritDoc
		 */
		public function create(viewComponent:Object):IMediator
		{
			var mediator:IMediator = mediatorByView[viewComponent];
			if (mediator == null)
			{
				var viewClassName:String = reflector.getFQCN(viewComponent);
				var config:MappingConfig = mappingConfigByViewClassName[viewClassName];
				if (config)
				{
					mediator = new config.mediatorClass();
					logger.info('Mediator Constructed: (' + mediator + ') with view component (' + viewComponent + ') of type (' + viewClassName + ')');
					injector.bindValue(config.typedViewClass, viewComponent);
					injector.injectInto(mediator);
					injector.unbind(config.typedViewClass);
					register(viewComponent, mediator);
				}
			}
			return mediator;
		}
		
		/**
		 * @inheritDoc
		 */
		public function register(viewComponent:Object, mediator:IMediator):void
		{
			injector.bindValue(reflector.getClass(mediator), mediator);
			mediatorByView[viewComponent] = mediator;
			mappingConfigByView[viewComponent] = mappingConfigByViewClassName[reflector.getFQCN(viewComponent)];
			mediator.setViewComponent(viewComponent);
			mediator.preRegister();
			logger.info('Mediator Registered: (' + mediator + ') with View Component (' + viewComponent + ')');
		}
		
		/**
		 * @inheritDoc
		 */
		public function remove(mediator:IMediator):IMediator
		{
			if (mediator)
			{
				var viewComponent:Object = mediator.getViewComponent();
				delete mediatorByView[viewComponent];
				delete mappingConfigByView[viewComponent];
				mediator.preRemove();
				mediator.setViewComponent(null);
				injector.unbind(reflector.getClass(mediator));
				logger.info('Mediator Removed: (' + mediator + ') with View Component (' + viewComponent + ')');
			}
			return mediator;
		}
		
		/**
		 * @inheritDoc
		 */
		public function removeByView(viewComponent:Object):IMediator
		{
			return remove(retrieve(viewComponent));
		}
		
		/**
		 * @inheritDoc
		 */
		public function retrieve(viewComponent:Object):IMediator
		{
			return mediatorByView[viewComponent];
		}
		
		/**
		 * @inheritDoc
		 */
		public function hasMediator(viewComponent:Object):Boolean
		{
			return mediatorByView[viewComponent] != null;
		}
		
		public function destroy():void
		{
			removeListeners();
			injector = null;
			mediatorByView = null;
			mappingConfigByView = null;
			mappingConfigByViewClassName = null;
			contextView = null;
		}
		
		// Protected Methods //////////////////////////////////////////////////
		protected function initializeListeners():void
		{
			contextView.addEventListener(Event.ADDED_TO_STAGE, onViewAdded, useCapture, 0, true);
			contextView.addEventListener(Event.REMOVED_FROM_STAGE, onViewRemoved, useCapture, 0, true);
		}
		
		protected function removeListeners():void
		{
			contextView.removeEventListener(Event.ADDED_TO_STAGE, onViewAdded, useCapture);
			contextView.removeEventListener(Event.REMOVED_FROM_STAGE, onViewRemoved, useCapture);
		}
		
		protected function onViewAdded(e:Event):void
		{
			var config:MappingConfig = mappingConfigByViewClassName[reflector.getFQCN(e.target)];
			if (config && config.autoRegister)
			{
				create(e.target);
			}
		}
		
		protected function onViewRemoved(e:Event):void
		{
			var config:MappingConfig = mappingConfigByView[e.target];
			if (config && config.autoRemove)
			{
				// Flex work-around...
				logger.info('MediatorMap might have mistakenly lost an ' + e.target + ', double checking...');
				DelayedFunctionQueue.add(possiblyRemoveMediator, e.target);
			}
		}
		
		// Private Methods ////////////////////////////////////////////////////
		private function possiblyRemoveMediator(viewComponent:DisplayObject):void
		{
			if (viewComponent.stage == null)
			{
				removeByView(viewComponent);
			}
			else
			{
				logger.info('MediatorMap false alarm for ' + viewComponent);
			}
		}
	
	}

}

class MappingConfig
{
	public var mediatorClass:Class;
	public var typedViewClass:Class;
	public var autoRegister:Boolean;
	public var autoRemove:Boolean;
}